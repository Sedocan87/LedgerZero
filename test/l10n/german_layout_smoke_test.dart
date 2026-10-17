import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/l10n/default_category_names.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/account_detail_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/reconciliation_screen.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_screen.dart';
import 'package:ledger_zero/presentation/screens/categories/categories_screen.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/screens/import/csv_import_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/budget_setup_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/completion_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:ledger_zero/presentation/screens/payees/payees_screen.dart';
import 'package:ledger_zero/presentation/screens/reports/reports_screen.dart';
import 'package:ledger_zero/presentation/screens/rules/add_edit_rule_screen.dart';
import 'package:ledger_zero/presentation/screens/rules/rules_screen.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/add_edit_scheduled_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/scheduled_transactions_screen.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/legacy_unlock_view.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
import 'package:ledger_zero/presentation/screens/onboarding/security_setup_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/accessibility_settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/backup_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/faq_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/security_settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_settings_screen.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/presentation/screens/settings/help_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/import/ynab/ynab_import_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/income/income_settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/settings_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/user_guide_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/natural_language_input_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:ledger_zero/presentation/widgets/scaffold_with_navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/security_fakes.dart';
import '../helpers/test_database.dart';

/// Pumps the main screens in German on a narrow phone (360 dp wide) and
/// fails on any layout overflow: German labels are often much longer than
/// the English ones.
void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  late InMemorySecureStore store;
  final german = lookupAppLocalizations(const Locale('de'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'settings_language': 'de',
      'settings_currency': 'EUR',
      // First-run tutorials cover the screen; they are tested separately.
      'tutorial_completed_budget_screen_intro': true,
      'tutorial_completed_transaction_entry_intro': true,
      'tutorial_completed_sync_setup_intro': true,
    });
    prefs = await SharedPreferences.getInstance();
    store = InMemorySecureStore();
    t = TestDatabase(seedName: defaultCategoryNames(german));
    final giro = await t.addAccount(
      id: 'giro',
      name: 'Girokonto Sparkasse Musterstadt',
      currency: 'EUR',
      startingBalance: 1234567,
    );
    await t.addAccount(
      id: 'tagesgeld',
      name: 'Tagesgeldkonto',
      type: AccountType.savings,
      currency: 'EUR',
      startingBalance: 2500000,
    );
    final groceries = await t.categoryId(german.seedCatGroceries);
    await t.addTransaction(
      accountId: giro.id,
      amount: -8765,
      categoryId: groceries,
    );
    await t.addTransaction(accountId: giro.id, amount: 320000);
  });

  tearDown(() => t.close());

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(t.db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(store),
    legacySecureStoreProvider.overrideWithValue(InMemorySecureStore()),
    keyVaultProvider.overrideWithValue(KeyVault(store, newKdfParams: fastKdf)),
    biometricKeyStoreProvider.overrideWithValue(
      FakeBiometricKeyStore(available: false),
    ),
  ];

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/screen',
      routes: [GoRoute(path: '/screen', builder: (context, state) => screen)],
      errorBuilder: (context, state) => const SizedBox(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Budget': () => const BudgetScreen(),
    'Accounts': () => const AccountsScreen(),
    'Account detail': () => const AccountDetailScreen(accountId: 'giro'),
    'Add account': () => const AddEditAccountScreen(),
    'First account': () => const AddEditAccountScreen(firstAccount: true),
    'Reconcile': () => const ReconciliationScreen(accountId: 'giro'),
    'Transactions': () => const TransactionsScreen(),
    'Add transaction': () => const AddEditTransactionScreen(),
    'Quick add': () => const NaturalLanguageInputScreen(),
    'Reports': () => const ReportsScreen(),
    'Categories': () => const CategoriesScreen(),
    'Add category': () => const AddEditCategoryScreen(),
    'Payees': () => const PayeesScreen(),
    'Rules': () => const RulesScreen(),
    'Add rule': () => const AddEditRuleScreen(),
    'Scheduled': () => const ScheduledTransactionsScreen(),
    'Add scheduled': () => const AddEditScheduledTransactionScreen(),
    'Income': () => const IncomeSettingsScreen(),
    'Settings': () => const SettingsScreen(),
    'Accessibility': () => const AccessibilitySettingsScreen(),
    'Security settings': () => const SecuritySettingsScreen(),
    'Backup': () => const BackupScreen(),
    'Sync settings': () => const SyncSettingsScreen(),
    'Security setup': () => const SecuritySetupScreen(),
    'Lock screen': () => const LockScreen(),
    'Legacy unlock': () => Scaffold(
      body: SingleChildScrollView(
        child: LegacyUnlockView(onUnlocked: (_) async {}, onReset: () {}),
      ),
    ),
    'Help': () => const HelpScreen(),
    'FAQ': () => const FaqScreen(),
    'User guide': () => const UserGuideScreen(),
    'CSV import': () => const CsvImportScreen(),
    'YNAB import': () => const YnabImportScreen(),
    'Onboarding': () => const OnboardingScreen(),
    'Budget setup': () => const BudgetSetupScreen(),
    'Onboarding complete': () => const CompletionScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} fits 360 dp in German', (tester) async {
      await pumpScreen(tester, entry.value());
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  testWidgets('the savings transfer hint fits 360 dp in German', (
    tester,
  ) async {
    final savings = await t.categoryId(german.seedCatSavings);
    await tester.runAsync(
      () => t.budgeting.setCategoryBudgetedAmount(
        savings,
        50000,
        CalendarDate.startOfMonthUtc(CalendarDate.today()),
      ),
    );
    await pumpScreen(tester, const BudgetScreen());
    final hint = find.text(german.hintSavingsTransfer);
    await tester.scrollUntilVisible(hint, 300);
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    expect(find.byKey(const Key('info.saving')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('budget tutorial steps fit 360 dp in German', (tester) async {
    await prefs.remove('tutorial_completed_budget_screen_intro');
    await pumpScreen(tester, const BudgetScreen());
    expect(find.text(german.tutBudgetWelcomeTitle), findsOneWidget);
    for (var step = 0; step < 3; step++) {
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(german.tutorialNext));
      await tester.pumpAndSettle();
    }
    expect(find.text(german.tutorialFinish), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('transaction tutorial steps fit 360 dp in German', (
    tester,
  ) async {
    await prefs.remove('tutorial_completed_transaction_entry_intro');
    await pumpScreen(tester, const AddEditTransactionScreen());
    expect(find.text(german.tutTxAmountTitle), findsOneWidget);
    for (var step = 0; step < 3; step++) {
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(german.tutorialNext));
      await tester.pumpAndSettle();
    }
    expect(find.text(german.tutorialFinish), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('bottom navigation fits 360 dp in German', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    StatefulShellBranch branch(String path) => StatefulShellBranch(
      routes: [
        GoRoute(path: path, builder: (context, state) => const SizedBox()),
      ],
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              ScaffoldWithNavBar(navigationShell: shell),
          branches: [
            branch('/'),
            branch('/budget'),
            branch('/accounts'),
            branch('/transactions'),
            branch('/reports'),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(german.transactions), findsWidgets);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
