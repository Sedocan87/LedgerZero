import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/core/money/currency.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAccountRepository implements AccountRepository {
  MockAccountRepository({this.existing, this.accounts = const []});

  final Account? existing;

  /// What [watchAllAccounts] emits (the other accounts).
  final List<Account> accounts;
  Account? created;
  Account? updated;

  @override
  Future<void> createAccount(Account account) async => created = account;

  @override
  Future<void> updateAccount(Account account) async => updated = account;

  @override
  Future<Account?> getAccountById(String id) async => existing;

  @override
  Future<List<Account>> getAllAccounts() async => [];
  @override
  Stream<List<Account>> watchAllAccounts() => Stream.value(accounts);
  @override
  Stream<Account?> watchAccount(String id) => Stream.value(null);
  @override
  Future<void> deleteAccount(String id) async {}
  @override
  Future<Map<String, int>> getAccountBalances() async => {};
  @override
  Stream<Map<String, int>> watchAccountBalances() => Stream.value({});
  @override
  Future<int> getAccountBalance(String id) async => 0;
  @override
  Future<int> getClearedBalance(String id, {DateTime? upTo}) async => 0;
  @override
  Future<bool> wasSynced(String id) async => false;

  @override
  Future<int> getBudgetStartingBalance() async => 0;
}

final _germanFormatter = appFormatterProvider.overrideWithValue(
  AppFormatter(locale: 'de', currency: 'EUR', decimalSeparator: ','),
);

void main() {
  testWidgets('AddEditAccountScreen form validation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddEditAccountScreen(),
        ),
      ),
    );

    // Scroll down to reveal button
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    // Tap save without entering data
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    // Scroll up to see error
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();

    // Expect validation error
    expect(find.text('Please enter an account name'), findsOneWidget);
  });

  testWidgets('AddEditAccountScreen accessibility check', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddEditAccountScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check Semantics for Color Picker using exact string match
    expect(find.bySemanticsLabel('Color 1'), findsOneWidget);
  });

  testWidgets('saves a decimal-comma starting balance as minor units', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = MockAccountRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          _germanFormatter,
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddEditAccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Girokonto');
    await tester.enterText(find.byType(TextFormField).at(1), '1.234,56');
    final saveButton = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repo.created, isNotNull);
    expect(repo.created!.name, 'Girokonto');
    expect(repo.created!.startingBalance, 123456);
    // New accounts default to the Settings currency.
    expect(repo.created!.currency, 'EUR');
  });

  testWidgets('rejects an invalid starting balance', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = MockAccountRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          _germanFormatter,
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddEditAccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Girokonto');
    await tester.enterText(find.byType(TextFormField).at(1), 'abc');
    final saveButton = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repo.created, isNull);
    expect(find.text('Invalid number'), findsOneWidget);
  });

  testWidgets('edit mode pre-fills the balance and keeps the currency', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = MockAccountRepository(
      existing: const Account(
        id: 'a1',
        name: 'Sparkonto',
        type: AccountType.savings,
        currency: 'SEK', // not in supportedCurrencyCodes
        startingBalance: 123456,
        balance: 200000,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          _germanFormatter,
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddEditAccountScreen(accountId: 'a1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1234,56'), findsOneWidget);
    expect(find.text('SEK'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '-10,5');
    final saveButton = find.widgetWithText(ElevatedButton, 'Save Changes');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repo.updated, isNotNull);
    expect(repo.updated!.startingBalance, -1050);
    expect(repo.updated!.currency, 'SEK');
  });

  Future<void> pumpForm(
    WidgetTester tester,
    MockAccountRepository repo, {
    String? accountId,
    bool firstAccount = false,
    bool keepPrefs = false,
  }) async {
    if (!keepPrefs) {
      SharedPreferences.setMockInitialValues({});
    }
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AddEditAccountScreen(
            accountId: accountId,
            firstAccount: firstAccount,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a new account can be kept out of the budget', (tester) async {
    final repo = MockAccountRepository();
    await pumpForm(tester, repo);

    await tester.enterText(find.byType(TextFormField).at(0), 'Brokerage');
    await tapAndSettle(tester, find.byKey(const Key('account.onBudget')));
    await tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Create Account'),
    );

    expect(repo.created!.onBudget, isFalse);
  });

  testWidgets('taking an account out of the budget asks first', (tester) async {
    final repo = MockAccountRepository(
      existing: const Account(
        id: 'a1',
        name: 'Savings',
        type: AccountType.savings,
      ),
    );
    await pumpForm(tester, repo, accountId: 'a1');

    await tapAndSettle(tester, find.byKey(const Key('account.onBudget')));
    final save = find.widgetWithText(ElevatedButton, 'Save Changes');

    // Cancel keeps the account unchanged.
    await tapAndSettle(tester, save);
    expect(find.text('Change what you budget?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.updated, isNull);

    await tapAndSettle(tester, save);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repo.updated!.onBudget, isFalse);
  });
  bool includedInBudget(WidgetTester tester) => tester
      .widget<SwitchListTile>(find.byKey(const Key('account.onBudget')))
      .value;

  Future<void> chooseType(WidgetTester tester, String label) async {
    await tapAndSettle(
      tester,
      find.byType(DropdownButtonFormField<AccountType>),
    );
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('a new savings or investment account starts outside the '
      'budget; switching back to checking includes it again', (tester) async {
    await pumpForm(tester, MockAccountRepository());
    expect(includedInBudget(tester), isTrue);

    await chooseType(tester, 'Investment');
    expect(includedInBudget(tester), isFalse);
    await chooseType(tester, 'Savings');
    expect(includedInBudget(tester), isFalse);
    await chooseType(tester, 'Checking');
    expect(includedInBudget(tester), isTrue);
  });

  testWidgets('a switch the user set is kept when the type changes, and '
      'the subtitle says what the state means', (tester) async {
    final repo = MockAccountRepository();
    await pumpForm(tester, repo);
    expect(find.textContaining('On: its balance'), findsOneWidget);

    // Chosen explicitly: Savings no longer flips it off.
    await tapAndSettle(tester, find.byKey(const Key('account.onBudget')));
    expect(includedInBudget(tester), isFalse);
    expect(find.textContaining('Off: not budgeted'), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('account.onBudget')));
    expect(includedInBudget(tester), isTrue);
    await chooseType(tester, 'Savings');
    expect(includedInBudget(tester), isTrue);
    expect(find.textContaining('On: its balance'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Emergency fund');
    // Pressed directly: after the dropdown closed, the button cannot be
    // scrolled into the 600 px test viewport.
    tester
        .widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Create Account'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(repo.created!.type, AccountType.savings);
    expect(repo.created!.onBudget, isTrue);
  });

  testWidgets('the first account stays in the budget whatever its type', (
    tester,
  ) async {
    await pumpForm(tester, MockAccountRepository(), firstAccount: true);
    await chooseType(tester, 'Savings');
    expect(includedInBudget(tester), isTrue);
  });

  Future<void> chooseCurrency(WidgetTester tester, String code) async {
    await tapAndSettle(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text(code).last);
    await tester.pumpAndSettle();
  }

  List<String> offeredCurrencies(WidgetTester tester) => tester
      .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .items!
      .map((i) => i.value!)
      .toList();

  testWidgets('the first on-budget account sets the budget currency', (
    tester,
  ) async {
    final repo = MockAccountRepository();
    await pumpForm(tester, repo, firstAccount: true);
    expect(find.text('Budget currency'), findsOneWidget);
    expect(offeredCurrencies(tester), supportedCurrencyCodes);

    await tester.enterText(find.byType(TextFormField).at(0), 'Giro');
    await chooseCurrency(tester, 'CHF');
    await tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Create Account'),
    );

    expect(repo.created!.currency, 'CHF');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AddEditAccountScreen)),
    );
    expect(container.read(settingsProvider).currency, 'CHF');
    expect(
      container.read(sharedPreferencesProvider).getString('settings_currency'),
      'CHF',
    );
  });

  testWidgets('a later on-budget account is fixed to the budget currency; '
      'off-budget accounts may use any', (tester) async {
    SharedPreferences.setMockInitialValues({'settings_currency': 'EUR'});
    final repo = MockAccountRepository(
      accounts: const [
        Account(
          id: 'a1',
          name: 'Giro',
          type: AccountType.checking,
          currency: 'EUR',
        ),
      ],
    );
    await pumpForm(tester, repo, keepPrefs: true);
    await tester.enterText(find.byType(TextFormField).at(0), 'Card');

    expect(find.text('Budget currency'), findsNothing);
    expect(offeredCurrencies(tester), ['EUR']);
    expect(find.textContaining('budget currency (EUR)'), findsOneWidget);

    await tapAndSettle(tester, find.byKey(const Key('account.onBudget')));
    expect(offeredCurrencies(tester), supportedCurrencyCodes);
    await chooseCurrency(tester, 'USD');

    // Back into the budget: the budget currency again.
    await tapAndSettle(tester, find.byKey(const Key('account.onBudget')));
    expect(offeredCurrencies(tester), ['EUR']);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Create Account'),
    );
    expect(repo.created!.currency, 'EUR');
  });

  testWidgets('a closed on-budget account does not fix the currency', (
    tester,
  ) async {
    final repo = MockAccountRepository(
      accounts: const [
        Account(
          id: 'a1',
          name: 'Old',
          type: AccountType.checking,
          currency: 'EUR',
          isClosed: true,
        ),
      ],
    );
    await pumpForm(tester, repo);
    expect(find.text('Budget currency'), findsOneWidget);
  });
}
