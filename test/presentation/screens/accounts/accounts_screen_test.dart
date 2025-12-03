import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
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
}

void main() {
  testWidgets('AccountsScreen shows accounts list', (WidgetTester tester) async {
    const tAccount = Account(
      id: '1',
      name: 'Checking',
      type: AccountType.checking,
      currentBalance: 1000.0,
      currency: 'USD',
    );

    final fakeRepo = FakeAccountRepository(Stream.value([tAccount]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Checking'), findsOneWidget);
    expect(find.text('\$1,000.00'), findsOneWidget);
  });

  testWidgets('AccountsScreen shows empty state', (WidgetTester tester) async {
    final fakeRepo = FakeAccountRepository(Stream.value([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Create your first account to get started with budgeting.'), findsOneWidget);
  });
}
