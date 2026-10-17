import 'dart:convert';
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
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/security_setup_screen.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/device_key_store.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/security_fakes.dart';

void main() {
  late Directory dir;
  late InMemorySecureStore store;
  late KeyVault vault;
  late SharedPreferences prefs;
  late FakeAppLockAuthenticator appLock;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lz_flows_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    store = InMemorySecureStore();
    vault = KeyVault(store, newKdfParams: fastKdf);
    appLock = FakeAppLockAuthenticator();
    SharedPreferences.setMockInitialValues({'user_onboarded': true});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    Widget screen, {
    SecureStore? secureStore,
  }) async {
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
        secureStoreProvider.overrideWithValue(secureStore ?? store),
        legacySecureStoreProvider.overrideWithValue(InMemorySecureStore()),
        keyVaultProvider.overrideWithValue(vault),
        biometricKeyStoreProvider.overrideWithValue(
          FakeBiometricKeyStore(available: false),
        ),
        appLockAuthenticatorProvider.overrideWithValue(appLock),
      ],
    );
    addTearDown(() async {
      await container.read(sessionProvider.notifier).close();
      container.dispose();
    });
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
    await tester.pump();
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

  String? storedDeviceKey() => store.values[DeviceKeyStore.storageKey];

  Future<List<int>> storeDeviceKey() async {
    final dek = secureRandomBytes(32);
    store.values[DeviceKeyStore.storageKey] = base64Encode(dek);
    return dek;
  }

  group('onboarding', () {
    setUp(() async {
      await prefs.setBool('user_onboarded', false);
    });

    testWidgets('creates the device key, opens the session and offers the '
        'app lock', (tester) async {
      final container = await pumpApp(tester, const SecuritySetupScreen());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('setup_app_lock')))
            .value,
        isTrue,
        reason: 'on by default when the phone has a screen lock',
      );

      await tester.tap(find.text('Continue'));
      await waitUntil(tester, () => shows('budget setup'));

      expect(storedDeviceKey(), isNotNull);
      expect(store.values.containsKey(KeyVault.storageKey), isFalse);
      expect(container.read(appLockStateProvider), AppLockState.unlocked);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(appLockEnabledProvider), isTrue);
      expect(
        base64Decode(storedDeviceKey()!),
        container.read(sessionProvider).key!.bytes,
      );
    });

    testWidgets('without a screen lock the app lock cannot be turned on', (
      tester,
    ) async {
      appLock.screenLock = false;
      final container = await pumpApp(tester, const SecuritySetupScreen());
      await tester.pumpAndSettle();
      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('setup_app_lock')),
      );
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);

      await tester.tap(find.text('Continue'));
      await waitUntil(tester, () => shows('budget setup'));
      expect(container.read(appLockEnabledProvider), isFalse);
    });
  });

  group('lock screen', () {
    testWidgets('app lock off: opens the session and the UI at once', (
      tester,
    ) async {
      final dek = await storeDeviceKey();
      final container = await pumpApp(tester, const LockScreen());

      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(container.read(sessionProvider).key!.bytes, dek);
      expect(appLock.prompts, 0);
    });

    testWidgets('app lock on: the database opens before the prompt; a '
        'cancelled prompt keeps only the UI locked', (tester) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      appLock.result = AppLockResult.cancelled;
      await storeDeviceKey();
      final container = await pumpApp(tester, const LockScreen());

      await waitUntil(tester, () => appLock.prompts == 1);
      expect(container.read(appLockStateProvider), AppLockState.unlocked);
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(find.text('LedgerZero is locked'), findsOneWidget);

      appLock.result = AppLockResult.success;
      await tester.tap(find.byKey(const Key('lock_unlock')));
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(appLock.prompts, 2);
    });

    testWidgets('after the auto-lock the open session is kept and only the '
        'prompt is shown', (tester) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      final dek = await storeDeviceKey();
      final container = await pumpApp(tester, const SizedBox());
      container.read(sessionProvider.notifier).open(Uint8List.fromList(dek));
      final key = container.read(sessionProvider).key;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: LockScreen(),
          ),
        ),
      );
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(appLock.prompts, 1);
      expect(container.read(sessionProvider).key, same(key));
    });

    testWidgets('a lock on the way to the background prompts only when the '
        'app is back in the foreground', (tester) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      final dek = await storeDeviceKey();
      final container = await pumpApp(tester, const SizedBox());
      container.read(sessionProvider.notifier).open(Uint8List.fromList(dek));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: LockScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      // Not over the home screen or another app.
      expect(appLock.prompts, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(appLock.prompts, 1);
    });

    testWidgets('a failing key store shows "try again", never the reset', (
      tester,
    ) async {
      await storeDeviceKey();
      final failing = _FailingSecureStore(store, failures: 3);
      final container = await pumpApp(
        tester,
        const LockScreen(),
        secureStore: failing,
      );
      await waitUntil(
        tester,
        () => find.byKey(const Key('lock_retry')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('login_reset_app')), findsNothing);
      expect(container.read(appLockStateProvider), AppLockState.locked);

      // A transient failure: the next try (with retries) works.
      failing.failures = 1;
      await tester.tap(find.byKey(const Key('lock_retry')));
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
    });

    testWidgets('a removed screen lock turns the app lock off instead of '
        'locking the user out', (tester) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      appLock.screenLock = false;
      await storeDeviceKey();
      final container = await pumpApp(tester, const LockScreen());

      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(container.read(appLockEnabledProvider), isFalse);
    });

    testWidgets('missing key: "Reset app" needs the typed word, then '
        'factory-resets and returns to onboarding', (tester) async {
      await prefs.setBool('marker_pref', true);
      final dbFile = File('${dir.path}/db.sqlite')..writeAsStringSync('x');
      final walFile = File('${dir.path}/db.sqlite-wal')..writeAsStringSync('x');
      final container = await pumpApp(tester, const LockScreen());

      await waitUntil(
        tester,
        () => find.byKey(const Key('login_reset_app')).evaluate().isNotEmpty,
      );
      await tester.tap(find.byKey(const Key('login_reset_app')));
      await tester.pumpAndSettle();
      TextButton confirm() => tester.widget<TextButton>(
        find.byKey(const Key('login_reset_confirm')),
      );
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
  });

  group('installs with a master password', () {
    testWidgets('unlock once with the password: the key moves to the device '
        'key store and the vault is deleted', (tester) async {
      final pending = await tester.runAsync(() async {
        final p = await vault.build('master password 1');
        await vault.save(p.record);
        return p;
      });
      final container = await pumpApp(tester, const LockScreen());
      await waitUntil(tester, () => shows('Unlock one last time'));

      await tester.enterText(find.byType(TextField), 'wrong password');
      await tester.tap(find.text('Unlock'));
      await waitUntil(tester, () => shows('Incorrect Password'));
      expect(container.read(appLockStateProvider), AppLockState.locked);

      await tester.enterText(find.byType(TextField), 'master password 1');
      await tester.tap(find.text('Unlock'));
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );

      expect(container.read(sessionProvider).key!.bytes, pending!.dek);
      expect(base64Decode(storedDeviceKey()!), pending.dek);
      expect(store.values.containsKey(KeyVault.storageKey), isFalse);
      expect(
        container.read(appLockEnabledProvider),
        isTrue,
        reason: 'a password user keeps a lock',
      );
    });

    testWidgets('the recovery key also works, without a new password', (
      tester,
    ) async {
      final pending = await tester.runAsync(() async {
        final p = await vault.build('forgotten password');
        await vault.save(p.record);
        return p;
      });
      final container = await pumpApp(tester, const LockScreen());
      await waitUntil(tester, () => shows('Use recovery key'));

      await tester.tap(find.text('Use recovery key'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        pending!.recoveryKey.format().toLowerCase(),
      );
      await tester.tap(find.text('Unlock'));
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );

      expect(base64Decode(storedDeviceKey()!), pending.dek);
      expect(store.values.containsKey(KeyVault.storageKey), isFalse);
    });
  });
}

/// Throws on the first [failures] reads, then reads from [inner].
class _FailingSecureStore implements SecureStore {
  _FailingSecureStore(this.inner, {required this.failures});

  final SecureStore inner;
  int failures;

  @override
  Future<String?> read(String key) async {
    if (failures > 0) {
      failures--;
      throw Exception('keystore busy');
    }
    return inner.read(key);
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> delete(String key) => inner.delete(key);
}
