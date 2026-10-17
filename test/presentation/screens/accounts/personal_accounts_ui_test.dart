import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/account_detail_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

/// Personal accounts in the UI: the Personal switch, the partner's accounts
/// in the list and their read-only screens.
void main() {
  late TestDatabase t;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_transaction_entry_intro': true,
    });
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });

  tearDown(() => t.close());

  /// An account as it arrives from the partner's phone.
  Future<void> addPartnersAccount(WidgetTester tester, String id) async {
    await tester.runAsync(() async {
      await t.addAccount(id: id, name: 'Their brokerage');
      await t.db.customStatement(
        'UPDATE accounts SET owner_id = ?, on_budget = 0, shared_balance = ? '
        'WHERE id = ?',
        ['partner-member', 300000, id],
      );
    });
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/screen'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(path: '/screen', builder: (_, _) => screen),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  SwitchListTile switchTile(WidgetTester tester, String key) =>
      tester.widget<SwitchListTile>(find.byKey(Key(key)));

  Future<void> save(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('account form', () {
    testWidgets('a personal account is created off-budget', (tester) async {
      await pump(tester, const AddEditAccountScreen());
      await tester.enterText(
        find.widgetWithText(AppTextField, 'Account Name'),
        'My brokerage',
      );
      await tester.tap(find.byKey(const Key('account.personal')));
      await tester.pumpAndSettle();

      final onBudget = switchTile(tester, 'account.onBudget');
      expect(onBudget.value, isFalse);
      expect(onBudget.onChanged, isNull);
      expect(
        find.text('Personal accounts stay outside the budget.'),
        findsOneWidget,
      );

      await save(tester, 'Create Account');
      final stored = (await tester.runAsync(t.accounts.getAllAccounts))!;
      expect(stored.single.owner, AccountOwner.me);
      expect(stored.single.onBudget, isFalse);
      await unmount(tester);
    });

    testWidgets('the first account outside the budget explains how to save '
        'into it, once', (tester) async {
      Future<void> create(String name) async {
        await pump(tester, const AddEditAccountScreen());
        await tester.enterText(
          find.widgetWithText(AppTextField, 'Account Name'),
          name,
        );
        await tester.tap(find.byKey(const Key('account.onBudget')));
        await tester.pumpAndSettle();
        await save(tester, 'Create Account');
      }

      await create('Brokerage');
      expect(find.byKey(const Key('hint.offBudgetAccount')), findsOneWidget);
      await tester.tap(find.text('Show me'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help.saving')), findsOneWidget);
      await unmount(tester);

      await create('Pension');
      expect(find.byKey(const Key('hint.offBudgetAccount')), findsNothing);
      expect(find.text('Account created'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the form explains type, budget and Personal', (tester) async {
      await pump(tester, const AddEditAccountScreen());
      for (final topic in ['accountTypes', 'onBudget', 'personal']) {
        expect(find.byKey(Key('info.$topic')), findsOneWidget);
      }
      await unmount(tester);
    });

    testWidgets('a shared account that already synced cannot become '
        'personal', (tester) async {
      await tester.runAsync(() async {
        await t.addAccount(id: 'chk', name: 'Checking');
        await t.db.customStatement(
          'INSERT INTO sync_row_versions (sync_table, row_id, version, '
          "device_id) VALUES ('accounts', 'chk', 1, 'other')",
        );
      });
      await pump(tester, const AddEditAccountScreen(accountId: 'chk'));

      expect(switchTile(tester, 'account.personal').onChanged, isNull);
      expect(
        find.textContaining('Already shared with your partner'),
        findsOneWidget,
      );
      await unmount(tester);
    });

    testWidgets('sharing a personal account asks first', (tester) async {
      await tester.runAsync(
        () =>
            t.addAccount(id: 'brk', name: 'Brokerage', owner: AccountOwner.me),
      );
      await pump(tester, const AddEditAccountScreen(accountId: 'brk'));
      await tester.tap(find.byKey(const Key('account.personal')));
      await tester.pumpAndSettle();
      await save(tester, 'Save Changes');

      expect(find.text('Share with your partner?'), findsOneWidget);
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      final stored = (await tester.runAsync(
        () => t.accounts.getAccountById('brk'),
      ))!;
      expect(stored.owner, AccountOwner.shared);
      await unmount(tester);
    });

    testWidgets('the first account has no Personal switch', (tester) async {
      await pump(tester, const AddEditAccountScreen(firstAccount: true));
      expect(find.byKey(const Key('account.personal')), findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('the account list shows the partner\'s accounts on their own '
      'and splits net worth', (tester) async {
    await tester.runAsync(() async {
      await t.addAccount(id: 'chk', name: 'Checking', startingBalance: 100000);
      await t.addAccount(
        id: 'mine',
        name: 'My brokerage',
        startingBalance: 50000,
        owner: AccountOwner.me,
      );
    });
    await addPartnersAccount(tester, 'theirs');
    await pump(tester, const AccountsScreen());

    expect(find.text("Your partner's accounts"), findsOneWidget);
    expect(find.textContaining('These are your partner'), findsOneWidget);
    expect(find.byKey(const Key('info.accounts')), findsOneWidget);
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text("PARTNER'S"), findsOneWidget);
    expect(find.text(r'$4,500.00'), findsOneWidget);
    for (final (key, amount) in [
      ('netWorth.shared', r'$1,000.00'),
      ('netWorth.me', r'$500.00'),
      ('netWorth.partner', r'$3,000.00'),
    ]) {
      expect(
        find.descendant(of: find.byKey(Key(key)), matching: find.text(amount)),
        findsOneWidget,
      );
    }
    // The partner's accounts come after the header.
    expect(
      tester.getTopLeft(find.text('Their brokerage')).dy,
      greaterThan(tester.getTopLeft(find.text("Your partner's accounts")).dy),
    );
    await unmount(tester);
  });

  testWidgets('the partner\'s account opens read-only', (tester) async {
    await addPartnersAccount(tester, 'theirs');
    await pump(tester, const AccountDetailScreen(accountId: 'theirs'));

    expect(find.byKey(const Key('account.partnerNotice')), findsOneWidget);
    expect(find.text(r'$3,000.00'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await unmount(tester);
  });

  testWidgets('a transfer into the partner\'s account cannot be edited', (
    tester,
  ) async {
    await tester.runAsync(
      () => t.addAccount(id: 'chk', name: 'Checking', startingBalance: 100000),
    );
    await addPartnersAccount(tester, 'theirs');
    await tester.runAsync(
      () => t.addTransaction(
        id: 'leg',
        accountId: 'chk',
        amount: -5000,
        transferAccountId: 'theirs',
        transferTransactionId: 'their-leg',
      ),
    );
    await pump(tester, const AddEditTransactionScreen(transactionId: 'leg'));

    expect(find.byKey(const Key('transaction.partnerNotice')), findsOneWidget);
    final saveButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.check),
    );
    expect(saveButton.onPressed, isNull);
    await unmount(tester);
  });

  testWidgets('pickers leave out the partner\'s accounts', (tester) async {
    await tester.runAsync(() => t.addAccount(id: 'chk', name: 'Checking'));
    await addPartnersAccount(tester, 'theirs');
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(t.db)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(accountsProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.runAsync(() => container.read(accountsProvider.future));

    final writable = container.read(writableAccountsProvider).value!;
    expect(writable.map((a) => a.id), ['chk']);
  });
}
