import 'dart:io';

import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/security_setup_screen.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import '../../../helpers/security_fakes.dart';

void main() {
  late Directory dir;
  late SharedPreferences prefs;
  late FakeAppLockAuthenticator appLock;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lz_flows_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    appLock = FakeAppLockAuthenticator();
    SharedPreferences.setMockInitialValues({'user_onboarded': true});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProviderContainer> pumpApp(WidgetTester tester, Widget screen) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(
          path: '/first-account',
          name: 'first-account',
          builder: (_, _) => const Text('first account'),
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
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
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

  /// Lets real file I/O run until [condition] holds.
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

  File dbFile() => File('${dir.path}/db.sqlite');

  /// A database of this version at [dbFile], with an account when
  /// [withAccount].
  Future<void> writeDatabase(WidgetTester tester, {bool withAccount = true}) =>
      tester.runAsync(() async {
        final db = AppDatabase(NativeDatabase(dbFile()));
        await db.customSelect('SELECT 1').get();
        if (withAccount) {
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(id: 'a', name: 'Cash', type: 'cash'),
              );
        }
        await db.close();
      });

  /// A database of an early test version (below the minimum schema).
  Future<void> writeOldDatabase(WidgetTester tester) async {
    await writeDatabase(tester);
    await tester.runAsync(() async {
      final db = sqlite3.open(dbFile().path);
      db.execute(
        'PRAGMA user_version = ${AppDatabase.minimumSchemaVersion - 1}',
      );
      db.close();
    });
  }

  group('onboarding', () {
    setUp(() async {
      await prefs.setBool('user_onboarded', false);
    });

    testWidgets('opens the session, offers the app lock and says that the '
        'data is lost with the phone', (tester) async {
      final container = await pumpApp(tester, const SecuritySetupScreen());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('setup_app_lock')))
            .value,
        isTrue,
        reason: 'on by default when the phone has a screen lock',
      );
      expect(find.byKey(const Key('setup_data_loss_warning')), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await waitUntil(tester, () => shows('first account'));

      expect(container.read(appLockStateProvider), AppLockState.unlocked);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(appLockEnabledProvider), isTrue);
      expect(container.read(authProvider).isOnboarded, isFalse);
    });

    testWidgets('an existing database with accounts is kept, not deleted', (
      tester,
    ) async {
      await writeDatabase(tester);
      final container = await pumpApp(tester, const SecuritySetupScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );

      expect(container.read(authProvider).isOnboarded, isTrue);
      expect(shows('first account'), isFalse);
      expect(
        find.text('Your existing data on this phone was found and kept.'),
        findsOneWidget,
      );
      final db = container.read(databaseProvider);
      final accounts = await tester.runAsync(
        () => db.select(db.accounts).get(),
      );
      expect(accounts!.single.name, 'Cash');
    });

    testWidgets('a database without accounts (an earlier onboarding stopped '
        'there) is opened and onboarding goes on', (tester) async {
      await writeDatabase(tester, withAccount: false);
      final container = await pumpApp(tester, const SecuritySetupScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await waitUntil(tester, () => shows('first account'));
      expect(container.read(authProvider).isOnboarded, isFalse);
      expect(await tester.runAsync(dbFile().exists), isTrue);
    });

    testWidgets('a damaged database or one of an early test version is '
        'replaced', (tester) async {
      for (final damaged in [true, false]) {
        await prefs.setBool('user_onboarded', false);
        if (damaged) {
          dbFile().writeAsStringSync('not a database');
        } else {
          await writeOldDatabase(tester);
        }
        final container = await pumpApp(tester, const SecuritySetupScreen());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await waitUntil(tester, () => shows('first account'));
        final db = container.read(databaseProvider);
        final accounts = await tester.runAsync(
          () => db.select(db.accounts).get(),
        );
        expect(accounts, isEmpty);
        await tester.runAsync(
          () => container.read(sessionProvider.notifier).close(),
        );
      }
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
      await waitUntil(tester, () => shows('first account'));
      expect(container.read(appLockEnabledProvider), isFalse);
    });
  });

  group('lock screen', () {
    testWidgets('app lock off: opens the session and the UI at once', (
      tester,
    ) async {
      await writeDatabase(tester);
      final container = await pumpApp(tester, const LockScreen());

      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(container.read(sessionProvider).isOpen, isTrue);
      expect(appLock.prompts, 0);
    });

    testWidgets('a new install (no database yet) opens a new one', (
      tester,
    ) async {
      final container = await pumpApp(tester, const LockScreen());
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(container.read(appLockStateProvider), AppLockState.unlocked);
    });

    testWidgets('app lock on: the database opens before the prompt; a '
        'cancelled prompt keeps only the UI locked', (tester) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      appLock.result = AppLockResult.cancelled;
      await writeDatabase(tester);
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
      final container = await pumpApp(tester, const SizedBox());
      container.read(sessionProvider.notifier).open();
      final db = container.read(databaseProvider);

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
      expect(container.read(databaseProvider), same(db));
    });

    testWidgets('a lock on the way to the background prompts only when the '
        'app is back in the foreground', (tester) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      final container = await pumpApp(tester, const SizedBox());
      container.read(sessionProvider.notifier).open();

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

    testWidgets('a database file that cannot be read is retried; the reset '
        'is offered only after three tries, next to "Retry"', (tester) async {
      await writeDatabase(tester);
      await tester.runAsync(() => Process.run('chmod', ['000', dbFile().path]));
      addTearDown(() => Process.run('chmod', ['644', dbFile().path]));
      final container = await pumpApp(tester, const LockScreen());
      for (var attempt = 1; attempt <= 2; attempt++) {
        await waitUntil(
          tester,
          () => find.byKey(const Key('lock_retry')).evaluate().isNotEmpty,
        );
        expect(find.textContaining('database file'), findsOneWidget);
        expect(find.byKey(const Key('login_reset_app')), findsNothing);
        expect(container.read(appLockStateProvider), AppLockState.locked);
        await tester.tap(find.byKey(const Key('lock_retry')));
        await tester.pump();
      }
      await waitUntil(
        tester,
        () => find.byKey(const Key('login_reset_app')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('lock_retry')), findsOneWidget);
      expect(await tester.runAsync(dbFile().exists), isTrue);

      // It passes: the next try opens the data.
      await tester.runAsync(() => Process.run('chmod', ['644', dbFile().path]));
      await tester.tap(find.byKey(const Key('lock_retry')));
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
    });

    testWidgets('a damaged database offers the reset at once, next to '
        '"Retry"', (tester) async {
      dbFile().writeAsStringSync('not a database');
      final container = await pumpApp(tester, const LockScreen());
      await waitUntil(
        tester,
        () => find.byKey(const Key('login_reset_app')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('lock_retry')), findsOneWidget);
      expect(find.textContaining('damaged'), findsOneWidget);
      expect(container.read(appLockStateProvider), AppLockState.locked);
    });

    testWidgets('a database of an early test version is not upgraded: the '
        'reset is offered', (tester) async {
      await writeOldDatabase(tester);
      final container = await pumpApp(tester, const LockScreen());
      await waitUntil(
        tester,
        () => find.byKey(const Key('login_reset_app')).evaluate().isNotEmpty,
      );
      expect(find.textContaining('early test version'), findsOneWidget);
      expect(container.read(appLockStateProvider), AppLockState.locked);
    });

    testWidgets('a failed prompt keeps the app locked and shows the reason', (
      tester,
    ) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      appLock.result = AppLockResult.failed;
      appLock.lastFailure = 'Too many attempts';
      final container = await pumpApp(tester, const LockScreen());

      await waitUntil(
        tester,
        () => find.byKey(const Key('lock_auth_failed')).evaluate().isNotEmpty,
      );
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(appLockEnabledProvider), isTrue);

      appLock.result = AppLockResult.success;
      await tester.tap(find.byKey(const Key('lock_unlock')));
      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
    });

    testWidgets('a removed screen lock turns the app lock off instead of '
        'locking the user out', (tester) async {
      await prefs.setBool(kAppLockEnabledKey, true);
      appLock.screenLock = false;
      final container = await pumpApp(tester, const LockScreen());

      await waitUntil(
        tester,
        () => container.read(authProvider).isAuthenticated,
      );
      expect(container.read(appLockEnabledProvider), isFalse);
    });

    testWidgets('damaged database: "Reset app" needs the typed word, then '
        'factory-resets and returns to onboarding', (tester) async {
      await prefs.setBool('marker_pref', true);
      final db = dbFile()..writeAsStringSync('not a database');
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
      expect(await tester.runAsync(db.exists), isFalse);
      expect(await tester.runAsync(walFile.exists), isFalse);
      expect(container.read(authProvider).isOnboarded, isFalse);
    });
  });
}
