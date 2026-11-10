import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_filter_provider.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class FakeAccountRepository implements AccountRepository {
  final Stream<List<Account>> accountsStream;
  FakeAccountRepository(this.accountsStream);

  @override
  Stream<List<Account>> watchAllAccounts() => accountsStream;

  @override
  Stream<Account?> watchAccount(String id) => Stream.value(null);

  @override
  Future<void> createAccount(Account account) async {}
  @override
  Future<void> deleteAccount(String id) async {}
  @override
  Future<Account?> getAccountById(String id) async => null;
  @override
  Future<List<Account>> getAllAccounts() async => [];
  @override
  Future<void> updateAccount(Account account) async {}
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

void main() {
  testWidgets('AccountsScreen shows accounts list', (
    WidgetTester tester,
  ) async {
    const tAccount = Account(
      id: '1',
      name: 'Checking',
      type: AccountType.checking,
      balance: 100000,
      currency: 'USD',
    );

    final fakeRepo = FakeAccountRepository(Stream.value([tAccount]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(fakeRepo),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The name, and the type on the second line.
    expect(find.text('Checking'), findsNWidgets(2));
    expect(find.text('\$1,000.00'), findsOneWidget);
    // One group heading; a single account gets no group total.
    expect(find.text('On budget'), findsOneWidget);
    expect(find.byKey(const Key('accounts.groupTotal.onBudget')), findsNothing);
  });

  testWidgets('AccountsScreen shows empty state', (WidgetTester tester) async {
    final fakeRepo = FakeAccountRepository(Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(fakeRepo),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Create your first account to get started with budgeting.'),
      findsOneWidget,
    );
  });

  testWidgets('(L4) accounts in several currencies get one net worth line '
      'per currency and no single total', (tester) async {
    const usd = Account(
      id: '1',
      name: 'Checking',
      type: AccountType.checking,
      balance: 100000,
      currency: 'USD',
    );
    const eur = Account(
      id: '2',
      name: 'Euro',
      type: AccountType.savings,
      balance: 5000,
      currency: 'EUR',
    );
    final fakeRepo = FakeAccountRepository(Stream.value([usd, eur]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(fakeRepo),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Net Worth'), findsOneWidget);
    expect(find.byKey(const Key('netWorth.currency.USD')), findsOneWidget);
    expect(find.byKey(const Key('netWorth.currency.EUR')), findsOneWidget);
    expect(find.text('€50.00'), findsNWidgets(2)); // card + banner line
    // Never one figure across currencies.
    expect(find.text('\$1,050.00'), findsNothing);
    expect(find.text('€1,050.00'), findsNothing);
  });

  testWidgets('(UI refresh) accounts are grouped on budget, off budget and '
      'closed, with group totals', (tester) async {
    const accounts = [
      Account(
        id: '1',
        name: 'Checking',
        type: AccountType.checking,
        balance: 100000,
        currency: 'USD',
      ),
      Account(
        id: '2',
        name: 'Visa',
        type: AccountType.credit,
        balance: -25000,
        currency: 'USD',
      ),
      Account(
        id: '3',
        name: 'Brokerage',
        type: AccountType.investment,
        balance: 500000,
        currency: 'USD',
        onBudget: false,
      ),
      Account(
        id: '4',
        name: 'Old savings',
        type: AccountType.savings,
        currency: 'USD',
        isClosed: true,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(
            FakeAccountRepository(Stream.value(accounts)),
          ),
          accountFilterProvider.overrideWith(
            (ref) => const AccountFilter(showClosed: true),
          ),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double top(Finder finder) => tester.getTopLeft(finder).dy;
    final onBudget = find.byKey(const Key('accounts.group.onBudget'));
    final offBudget = find.byKey(const Key('accounts.group.offBudget'));
    final closed = find.byKey(const Key('accounts.group.closed'));
    expect(top(onBudget), lessThan(top(find.text('Checking').first)));
    expect(top(find.text('Visa')), lessThan(top(offBudget)));
    expect(top(offBudget), lessThan(top(find.text('Brokerage'))));
    expect(top(find.text('Brokerage')), lessThan(top(closed)));
    expect(top(closed), lessThan(top(find.text('Old savings'))));

    // The budget group adds up; a group of one repeats nothing.
    expect(
      find.descendant(
        of: find.byKey(const Key('accounts.groupTotal.onBudget')),
        matching: find.text(r'$750.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('accounts.groupTotal.offBudget')),
      findsNothing,
    );

    // A card's debt is not flagged; balances use tabular figures.
    final visa = tester.widget<Text>(find.text(r'-$250.00'));
    expect(visa.style!.color, AppTheme.lightTheme.colorScheme.onSurface);
    expect(
      visa.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}
