import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/login_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/security_setup_screen.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/security_fakes.dart';

void main() {
  late Directory dir;
  late InMemorySecureStore store;
  late KeyVault vault;
  late SharedPreferences prefs;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lz_flows_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    store = InMemorySecureStore();
    vault = KeyVault(store, newKdfParams: fastKdf);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProviderContainer> pumpApp(WidgetTester tester, Widget screen) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: '/budget-setup',
          name: 'budget-setup',
          builder: (_, _) => const Text('budget setup'),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const Text('onboarding'),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(store),
        legacySecureStoreProvider.overrideWithValue(InMemorySecureStore()),
        keyVaultProvider.overrideWithValue(vault),
        biometricKeyStoreProvider.overrideWithValue(
          FakeBiometricKeyStore(available: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Lets real isolates (KDF) and file I/O run until [condition] holds.
  /// (pumpAndSettle would never return while a progress spinner shows.)
  Future<void> waitUntil(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(condition(), isTrue);
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  testWidgets(
    'onboarding shows the recovery key and only continues after "I saved it"',
    timeout: const Timeout(Duration(seconds: 90)),
    (tester) async {
      final container = await pumpApp(tester, const SecuritySetupScreen());

      await tester.enterText(find.byType(TextFormField).at(0), 'short');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Use at least 10 characters'), findsWidgets);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Correct Horse Battery 9',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Correct Horse Battery 9',
      );
      await tester.tap(find.text('Continue'));
      await waitUntil(tester, () => shows('Your recovery key'));
      expect(
        store.values,
        isEmpty,
        reason: 'nothing is saved before the confirmation',
      );
      final continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
      await waitUntil(tester, () => shows('budget setup'));

      expect(store.values.containsKey(KeyVault.storageKey), isTrue);
      expect(container.read(appLockStateProvider), AppLockState.unlocked);
      expect(find.text('budget setup'), findsOneWidget);
      final dek = await tester.runAsync(
        () => vault.unlockWithPassword('Correct Horse Battery 9'),
      );
      expect(dek, container.read(sessionProvider).key!.bytes);
    },
  );

  testWidgets('login: wrong password is refused, right password unlocks', (
    tester,
  ) async {
    final pending = await tester.runAsync(() async {
      final p = await vault.build('master password 1');
      await vault.save(p.record);
      return p;
    });
    final container = await pumpApp(tester, const LoginScreen());

    await tester.enterText(find.byType(TextField), 'wrong password');
    await tester.tap(find.text('Unlock'));
    await waitUntil(tester, () => shows('Incorrect Password'));
    expect(container.read(appLockStateProvider), AppLockState.locked);

    await tester.enterText(find.byType(TextField), 'master password 1');
    await tester.tap(find.text('Unlock'));
    await waitUntil(
      tester,
      () => container.read(appLockStateProvider) == AppLockState.unlocked,
    );
    expect(container.read(sessionProvider).key!.bytes, pending!.dek);
  });

  testWidgets('login with the recovery key forces a new password', (
    tester,
  ) async {
    final pending = await tester.runAsync(() async {
      final p = await vault.build('forgotten password');
      await vault.save(p.record);
      return p;
    });
    final container = await pumpApp(tester, const LoginScreen());

    await tester.tap(find.text('Use recovery key'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      pending!.recoveryKey.format().toLowerCase(),
    );
    await tester.tap(find.text('Unlock'));
    await waitUntil(tester, () => shows('Set a new password'));
    expect(container.read(appLockStateProvider), AppLockState.locked);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Brand New Passphrase 7',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Brand New Passphrase 7',
    );
    await tester.tap(find.text('Continue'));
    await waitUntil(
      tester,
      () => container.read(appLockStateProvider) == AppLockState.unlocked,
    );
    final dek = await tester.runAsync(
      () => vault.unlockWithPassword('Brand New Passphrase 7'),
    );
    expect(dek, pending.dek);
    final viaRecovery = await tester.runAsync(
      () => vault.unlockWithRecoveryKey(pending.recoveryKey.format()),
    );
    expect(viaRecovery, pending.dek);
  });

  testWidgets('missing key vault: "Reset app" needs the typed word, then '
      'factory-resets and returns to onboarding', (tester) async {
    await prefs.setBool('marker_pref', true);
    final dbFile = File('${dir.path}/db.sqlite')..writeAsStringSync('x');
    final walFile = File('${dir.path}/db.sqlite-wal')..writeAsStringSync('x');
    final container = await pumpApp(tester, const LoginScreen());
    expect(find.byKey(const Key('login_reset_app')), findsNothing);

    await tester.enterText(find.byType(TextField), 'any password');
    await tester.tap(find.text('Unlock'));
    await waitUntil(
      tester,
      () => find.byKey(const Key('login_reset_app')).evaluate().isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('login_reset_app')));
    await tester.pumpAndSettle();
    TextButton confirm() =>
        tester.widget<TextButton>(find.byKey(const Key('login_reset_confirm')));
    expect(confirm().onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('login_reset_confirm_field')),
      'reset ',
    );
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('login_reset_confirm')));
    await waitUntil(tester, () => shows('onboarding'));

    expect(prefs.getBool('marker_pref'), isNull);
    expect(await tester.runAsync(dbFile.exists), isFalse);
    expect(await tester.runAsync(walFile.exists), isFalse);
    expect(container.read(authProvider).isOnboarded, isFalse);
  });
}
