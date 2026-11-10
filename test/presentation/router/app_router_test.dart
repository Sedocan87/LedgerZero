// The app router's gates (onboarding, lock) and deep links while locked,
// with the real routes and screens on an in-memory database.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/reorder_categories_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/reorder_groups_screen.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/security_setup_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/presentation/widgets/security/lock_overlay.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/app_directories.dart';
import '../../helpers/security_fakes.dart';
import '../../helpers/test_database.dart';

class _NoBackupReminder extends Mock implements BackupScheduler {
  @override
  Future<void> checkBackupDue() async {}
}

void main() {
  late TestDatabase t;

  setUp(() {
    mockAppDirectories();
    t = TestDatabase();
  });
  tearDown(() => t.close());

  /// Pumps the real router. [onboarded] is what the app persisted; the app
  /// always starts locked.
  Future<ProviderContainer> pumpRouter(
    WidgetTester tester, {
    required bool onboarded,
  }) async {
    SharedPreferences.setMockInitialValues({
      'user_onboarded': onboarded,
      // The app lock is on and its prompt is dismissed: the app stays at
      // the lock screen until a test unlocks it.
      kAppLockEnabledKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = InMemorySecureStore();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(t.db),
        secureStoreProvider.overrideWithValue(store),
        backupSchedulerProvider.overrideWithValue(_NoBackupReminder()),
        appLockAuthenticatorProvider.overrideWithValue(
          FakeAppLockAuthenticator(result: AppLockResult.cancelled),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(routerProvider),
            // As in MyApp: a later lock covers the app.
            builder: (context, child) => LockOverlay(child: child!),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Unmounts the app and lets drift's stream cleanup timers fire before
  /// the database closes (otherwise the test fails on pending timers).
  Future<void> unmount(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  String location(ProviderContainer c) =>
      c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  /// Passing the app lock (the database itself is the test database).
  void unlock(ProviderContainer c) =>
      c.read(authProvider.notifier).setAuthenticated(true);

  testWidgets('not onboarded: every location goes to onboarding', (
    tester,
  ) async {
    final c = await pumpRouter(tester, onboarded: false);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(location(c), '/onboarding');

    for (final target in ['/', '/login', '/accounts', '/settings']) {
      c.read(routerProvider).go(target);
      await tester.pumpAndSettle();
      expect(location(c), '/onboarding', reason: target);
    }
    // The steps after the security step need the open database.
    c.read(routerProvider).go('/onboarding/first-account');
    await tester.pumpAndSettle();
    expect(location(c), '/onboarding');
    expect(c.read(pendingLocationProvider).value, isNull);
    await unmount(tester, c);
  });

  testWidgets('onboarded and locked: the app starts at the lock screen', (
    tester,
  ) async {
    final c = await pumpRouter(tester, onboarded: true);
    expect(location(c), '/login');
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await unmount(tester, c);
  });

  testWidgets(
    'unlocking opens Home; the tabs work; a later lock covers the app and '
    'unlocking returns to the same screen',
    (tester) async {
      final c = await pumpRouter(tester, onboarded: true);
      unlock(c);
      await tester.pumpAndSettle();
      expect(location(c), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LockScreen), findsNothing);

      // The lock screen and onboarding are not reachable while unlocked.
      c.read(routerProvider).go('/login');
      await tester.pumpAndSettle();
      expect(location(c), '/');
      c.read(routerProvider).go('/onboarding');
      await tester.pumpAndSettle();
      expect(location(c), '/');

      await tester.tap(find.text('Accounts').last);
      await tester.pumpAndSettle();
      expect(location(c), '/accounts');
      expect(find.byType(AccountsScreen), findsOneWidget);

      // Locking (auto-lock or "Lock now") hides the app but keeps it.
      final accounts = tester.state(find.byType(AccountsScreen));
      c.read(authProvider.notifier).setAuthenticated(false);
      await tester.pump();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(AccountsScreen), findsNothing);
      expect(find.byType(AccountsScreen, skipOffstage: false), findsOneWidget);
      expect(location(c), '/accounts');

      unlock(c);
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      expect(location(c), '/accounts');
      // The same screen, not a new one.
      expect(tester.state(find.byType(AccountsScreen)), same(accounts));
      await unmount(tester, c);
    },
  );

  testWidgets(
    'a deep link while locked shows the lock screen, then opens after unlock',
    (tester) async {
      final c = await pumpRouter(tester, onboarded: true);
      c.read(routerProvider).go('/settings/scheduled-transactions');
      await tester.pumpAndSettle();
      expect(location(c), '/login');
      expect(find.byType(LockScreen), findsOneWidget);
      expect(
        c.read(pendingLocationProvider).value,
        '/settings/scheduled-transactions',
      );

      unlock(c);
      await tester.pumpAndSettle();
      expect(location(c), '/settings/scheduled-transactions');
      expect(c.read(pendingLocationProvider).value, isNull);

      // Opened once; a later lock/unlock stays where the user is.
      c.read(authProvider.notifier).setAuthenticated(false);
      await tester.pump();
      unlock(c);
      await tester.pumpAndSettle();
      expect(location(c), '/settings/scheduled-transactions');
      expect(c.read(pendingLocationProvider).value, isNull);
      await unmount(tester, c);
    },
  );

  testWidgets('onboarding ends with the first account: saving it marks the app '
      'onboarded and opens the budget', (tester) async {
    final c = await pumpRouter(tester, onboarded: false);
    // The security step opened the session, then goes to 'first-account'.
    unlock(c);
    c.read(routerProvider).goNamed('first-account');
    await tester.pumpAndSettle();
    expect(location(c), '/onboarding/first-account');
    final form = tester.widget<AddEditAccountScreen>(
      find.byType(AddEditAccountScreen),
    );
    expect(form.firstAccount, isTrue);
    expect(form.finishesOnboarding, isTrue);
    expect(find.text('Budget currency'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Checking');
    // The focused field would scroll the form back after ensureVisible.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    // No salary yet: the app asks; skip it.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(c.read(authProvider).isOnboarded, isTrue);
    expect(location(c), '/budget');
    expect(find.byType(AddEditAccountScreen), findsNothing);
    await unmount(tester, c);
  });

  testWidgets('the first-account step needs the open session', (tester) async {
    final c = await pumpRouter(tester, onboarded: false);
    c.read(routerProvider).go('/onboarding/first-account');
    await tester.pumpAndSettle();
    expect(location(c), '/onboarding');
    await unmount(tester, c);
  });

  testWidgets('one router for the app\'s life: unlocking, locking and '
      'finishing onboarding re-run the redirect, not a new router', (
    tester,
  ) async {
    final c = await pumpRouter(tester, onboarded: false);
    final router = c.read(routerProvider);
    unlock(c);
    await tester.pumpAndSettle();
    expect(c.read(routerProvider), same(router));
    c.read(authProvider.notifier).setOnboarded(true);
    await tester.pumpAndSettle();
    expect(c.read(routerProvider), same(router));
    // Onboarding is done: the redirect left it for Home.
    expect(location(c), '/');
    c.read(authProvider.notifier).setAuthenticated(false);
    await tester.pump();
    unlock(c);
    await tester.pumpAndSettle();
    expect(c.read(routerProvider), same(router));
    expect(
      () => ChangeNotifier.debugAssertNotDisposed(router.routerDelegate),
      returnsNormally,
    );
    await unmount(tester, c);
  });

  testWidgets('the security step opens the first-account step and never '
      'returns to the onboarding slides', (tester) async {
    final dir = Directory.systemTemp.createTempSync('lz_router_');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );
    final c = await pumpRouter(tester, onboarded: false);
    final router = c.read(routerProvider);
    router.goNamed('security-setup');
    await tester.pumpAndSettle();
    expect(find.byType(SecuritySetupScreen), findsOneWidget);

    final visited = <String>[];
    void record() => visited.add(location(c));
    router.routerDelegate.addListener(record);
    addTearDown(() => router.routerDelegate.removeListener(record));

    await tester.tap(find.text('Continue'));
    for (
      var i = 0;
      i < 200 && find.byType(AddEditAccountScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    expect(c.read(authProvider).hasUnlocked, isTrue);
    expect(c.read(routerProvider), same(router));
    expect(location(c), '/onboarding/first-account');
    expect(find.byType(AddEditAccountScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(visited, isNot(contains('/onboarding')));
    expect(visited, isNot(contains('/')));
    await c.read(sessionProvider.notifier).close();
    await unmount(tester, c);
  });

  testWidgets('back from the first-account step returns to the security '
      'step, and Continue leads to the account step again without '
      'finishing onboarding', (tester) async {
    final dir = Directory.systemTemp.createTempSync('lz_router_');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );
    final c = await pumpRouter(tester, onboarded: false);
    final router = c.read(routerProvider);

    Future<void> continueToAccountStep() async {
      await tester.tap(find.text('Continue'));
      for (
        var i = 0;
        i < 200 && find.byType(AddEditAccountScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
    }

    router.goNamed('security-setup');
    await tester.pumpAndSettle();
    await continueToAccountStep();
    expect(location(c), '/onboarding/first-account');
    // The session (and so the database) this onboarding opened: going back
    // must not replace it.
    expect(c.read(sessionProvider).isOpen, isTrue);
    final session = c.read(databaseProvider);

    // System back, then the app bar's back arrow.
    for (final viaAppBar in [false, true]) {
      if (viaAppBar) {
        await tester.tap(find.byType(BackButton));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(SecuritySetupScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(c.read(authProvider).isOnboarded, isFalse);

      await continueToAccountStep();
      expect(find.byType(AddEditAccountScreen), findsOneWidget);
      expect(location(c), '/onboarding/first-account');
      expect(c.read(authProvider).isOnboarded, isFalse);
      expect(c.read(databaseProvider), same(session));
      expect(
        find.text('Your existing data on this phone was found and kept.'),
        findsNothing,
      );
    }
    await c.read(sessionProvider.notifier).close();
    await unmount(tester, c);
  });

  testWidgets('literal paths open their own screen, not a sibling :id route', (
    tester,
  ) async {
    final c = await pumpRouter(tester, onboarded: true);
    unlock(c);
    await tester.pumpAndSettle();

    Future<void> open(String path, Type screen) async {
      c.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(location(c), path);
      expect(find.byType(screen), findsOneWidget, reason: path);
    }

    await open('/budget/categories/reorder-groups', ReorderGroupsScreen);
    await open(
      '/budget/categories/reorder-categories/g1',
      ReorderCategoriesScreen,
    );
    await open('/budget/categories/add', AddEditCategoryScreen);
    expect(
      tester
          .widget<AddEditCategoryScreen>(find.byType(AddEditCategoryScreen))
          .categoryId,
      isNull,
    );
    await open('/accounts/add', AddEditAccountScreen);
    expect(
      tester
          .widget<AddEditAccountScreen>(find.byType(AddEditAccountScreen))
          .accountId,
      isNull,
    );
    await unmount(tester, c);
  });

  testWidgets('a route that needs its arguments goes Home when opened '
      'without them (a link or a restored location)', (tester) async {
    final c = await pumpRouter(tester, onboarded: true);
    unlock(c);
    await tester.pumpAndSettle();

    for (final path in [
      '/filtered-transactions',
      '/settings/import-csv/confirm',
    ]) {
      c.read(routerProvider).go('/accounts');
      await tester.pumpAndSettle();
      c.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
      expect(location(c), '/', reason: path);
      expect(find.byType(HomeScreen), findsOneWidget, reason: path);
    }
    await unmount(tester, c);
  });

  test('no :parameter route precedes a literal sibling anywhere', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    final offenders = <String>[];

    void check(List<RouteBase> routes, String prefix) {
      String? parameterSeen;
      for (final route in routes) {
        if (route is GoRoute) {
          final first = route.path.split('/').first;
          if (first.startsWith(':')) {
            parameterSeen ??= route.path;
          } else if (parameterSeen != null) {
            offenders.add('$prefix${route.path} after $prefix$parameterSeen');
          }
          check(route.routes, '$prefix${route.path}/');
        } else if (route is ShellRouteBase) {
          check(route.routes, prefix);
        }
      }
    }

    check(router.configuration.routes, '/');
    expect(offenders, isEmpty);
  });
}
