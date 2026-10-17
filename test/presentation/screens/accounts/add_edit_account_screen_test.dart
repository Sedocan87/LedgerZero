import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAccountRepository implements AccountRepository {
  MockAccountRepository({this.existing});

  final Account? existing;
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
  Stream<List<Account>> watchAllAccounts() => Stream.value([]);
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
  }) async {
    SharedPreferences.setMockInitialValues({});
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
          home: AddEditAccountScreen(accountId: accountId),
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
}
