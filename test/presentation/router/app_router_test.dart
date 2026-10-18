// The app router's gates (onboarding, lock) and deep links while locked,
// with the real routes and screens on an in-memory database.

import 'package:flutter/material.dart';
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
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:ledger_zero/presentation/widgets/security/lock_overlay.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/security_fakes.dart';
import '../../helpers/test_database.dart';

class _NoBackupReminder extends Mock implements BackupScheduler {
  @override
  Future<void> checkBackupDue() async {}
}

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  /// Pumps the real router. [onboarded] is what the app persisted; the app
  /// always starts locked.
  Future<ProviderContainer> pumpRouter(
    WidgetTester tester, {
    required bool onboarded,
  }) async {
    SharedPreferences.setMockInitialValues({'user_onboarded': onboarded});
    final prefs = await SharedPreferences.getInstance();
    final store = InMemorySecureStore();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(t.db),
        secureStoreProvider.overrideWithValue(store),
        legacySecureStoreProvider.overrideWithValue(InMemorySecureStore()),
        keyVaultProvider.overrideWithValue(
          KeyVault(store, newKdfParams: fastKdf),
        ),
        biometricKeyStoreProvider.overrideWithValue(
          FakeBiometricKeyStore(available: false),
        ),
        backupSchedulerProvider.overrideWithValue(_NoBackupReminder()),
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
    c.read(routerProvider).go('/onboarding/budget-setup');
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

  testWidgets('a rebuilt router disposes the previous one', (tester) async {
    final c = await pumpRouter(tester, onboarded: true);
    final before = c.read(routerProvider);
    // The first unlock rebuilds the router (it starts at the pending link).
    unlock(c);
    await tester.pumpAndSettle();
    final after = c.read(routerProvider);
    expect(after, isNot(same(before)));
    expect(
      () => ChangeNotifier.debugAssertNotDisposed(before.routerDelegate),
      throwsFlutterError,
    );
    expect(
      () => ChangeNotifier.debugAssertNotDisposed(after.routerDelegate),
      returnsNormally,
    );
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
