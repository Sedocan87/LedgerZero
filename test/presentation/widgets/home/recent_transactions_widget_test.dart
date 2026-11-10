import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_parts.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';

void main() {
  testWidgets('Home lists the latest transactions with the shared rows', (
    tester,
  ) async {
    final day = DateTime.utc(2026, 11, 10);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
          recentTransactionsProvider.overrideWith(
            (ref) => Stream.value([
              Transaction(
                id: '1',
                accountId: 'giro',
                payeeId: 'rewe',
                categoryId: 'groceries',
                date: day,
                amount: -4250,
              ),
              Transaction(
                id: '2',
                accountId: 'giro',
                date: day,
                amount: 250000,
                memo: 'Salary',
              ),
            ]),
          ),
          transactionLookupsProvider.overrideWithValue(
            const TransactionLookups(
              categories: {
                'groceries': Category(id: 'groceries', name: 'Groceries'),
              },
              payees: {'rewe': 'REWE'},
              accounts: {
                'giro': Account(
                  id: 'giro',
                  name: 'Girokonto',
                  type: AccountType.checking,
                ),
              },
              splitParents: {},
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: RecentTransactionsWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TransactionListItem), findsNWidgets(2));
    expect(find.text('REWE'), findsOneWidget);
    expect(find.text('Groceries · Girokonto'), findsOneWidget);
    // Without a payee the memo names the row.
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text(r'+$2,500.00'), findsOneWidget);
    expect(find.text(r'-$42.50'), findsOneWidget);
    // A glance, not a work list: no cleared toggles.
    expect(find.byType(IconButton), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('transaction.badge')),
        matching: find.byIcon(Icons.local_grocery_store),
      ),
      findsOneWidget,
    );
  });
}
