// A notification tap with the real router: the target opens on top of Home
// with the tab bar, so back always leads home (it used to replace the
// stack with [Settings, target], which has no tab bar and no way back).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/backup_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/add_edit_scheduled_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/scheduled_transactions_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/backup_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_settings_screen.dart';
import 'package:ledger_zero/presentation/widgets/security/lock_overlay.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
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

  /// Pumps the real router, onboarded and unlocked, on Home.
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'user_onboarded': true,
      'tutorial_completed_budget_screen_intro': true,
      'tutorial_completed_transaction_entry_intro': true,
      'tutorial_completed_sync_setup_intro': true,
    });
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
        appLockAuthenticatorProvider.overrideWithValue(
          FakeAppLockAuthenticator(),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: ref.watch(routerProvider),
            builder: (context, child) => LockOverlay(child: child!),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(authProvider.notifier).setAuthenticated(true);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    return container;
  }

  Future<void> unmount(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  GoRouter router(ProviderContainer c) => c.read(routerProvider);

  /// What the system back button does.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> tapNotification(
    WidgetTester tester,
    ProviderContainer c,
    String payload,
  ) async {
    await tester.runAsync(
      () => c.read(notificationTapRouterProvider).handleTap(payload),
    );
    await tester.pumpAndSettle();
  }

  void expectHomeWithTabs() {
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  }

  testWidgets('backup reminder: Backup opens, back leads to Settings with a '
      'back arrow, then to Home with the tab bar', (tester) async {
    final c = await pumpApp(tester);
    await tapNotification(tester, c, 'backup');
    expect(find.byType(BackupScreen), findsOneWidget);

    await back(tester);
    expect(find.byType(BackupScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(router(c).canPop(), isTrue);
    expect(find.byType(BackButton), findsOneWidget);

    await back(tester);
    expectHomeWithTabs();
    await unmount(tester, c);
  });

  testWidgets('sync failure: Sync settings opens on top of Home', (
    tester,
  ) async {
    final c = await pumpApp(tester);
    await tapNotification(tester, c, 'sync');
    expect(find.byType(SyncSettingsScreen), findsOneWidget);

    await back(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await back(tester);
    expectHomeWithTabs();
    await unmount(tester, c);
  });

  testWidgets('scheduled reminder: the schedule opens on top of the list, '
      'Settings and Home', (tester) async {
    await t.addAccount(id: 'acc', startingBalance: 10000);
    await t.scheduledTransactions.createScheduledTransaction(
      ScheduledTransaction(
        id: 's1',
        accountId: 'acc',
        amount: -300,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2099, 6, 1),
      ),
    );
    final c = await pumpApp(tester);
    await tapNotification(tester, c, 'scheduled:s1');
    expect(find.byType(AddEditScheduledTransactionScreen), findsOneWidget);

    await back(tester);
    expect(find.byType(ScheduledTransactionsScreen), findsOneWidget);
    await back(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await back(tester);
    expectHomeWithTabs();
    await unmount(tester, c);
  });

  testWidgets('a tap while another screen is open on top of a tab still '
      'ends with Home underneath', (tester) async {
    final c = await pumpApp(tester);
    // The user is somewhere deep: Budget tab, Settings pushed on top.
    router(c).go('/budget');
    await tester.pumpAndSettle();
    unawaited(router(c).push('/settings'));
    await tester.pumpAndSettle();

    await tapNotification(tester, c, 'backup');
    expect(find.byType(BackupScreen), findsOneWidget);
    await back(tester);
    await back(tester);
    expectHomeWithTabs();
    await unmount(tester, c);
  });

  testWidgets('budget alert: the Budget tab, with the tab bar', (tester) async {
    final c = await pumpApp(tester);
    await tapNotification(tester, c, 'budget:c1');
    expect(find.byType(BudgetScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await unmount(tester, c);
  });

  testWidgets('Settings as the only page (a restored or redirected location) '
      'has a back arrow that leads Home, and so does the back button', (
    tester,
  ) async {
    final c = await pumpApp(tester);
    router(c).go('/settings/backup');
    await tester.pumpAndSettle();
    await back(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(router(c).canPop(), isFalse);

    await tester.tap(find.byKey(const Key('settings.backHome')));
    await tester.pumpAndSettle();
    expectHomeWithTabs();

    router(c).go('/settings');
    await tester.pumpAndSettle();
    await back(tester);
    expectHomeWithTabs();
    await unmount(tester, c);
  });
}

void unawaited(Future<void> future) {}
