// Rendering and scrolling a 1,000-row transaction list stays within a
// generous time budget (the list must build lazily). Tagged `perf`.
@Tags(['perf'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {
  @override
  Stream<Set<String>> watchSplitParentIds() => Stream.value(const {});

  @override
  Stream<List<Transaction>> watchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  }) {
    // Generate a large list of transactions
    final transactions = List.generate(
      1000,
      (index) => Transaction(
        id: 'tx_$index',
        accountId: 'acc1',
        date: DateTime.now().subtract(Duration(days: index % 30)),
        amount: -1000,
        payeeId: 'payee1',
        categoryId: 'cat1',
        cleared: TransactionClearStatus.uncleared,
        approved: true,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return Stream.value(transactions);
  }
}

void main() {
  group('Performance', () {
    testWidgets('TransactionsScreen renders large list efficiently', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            transactionRepositoryProvider.overrideWithValue(
              MockTransactionRepository(),
            ),
            categoryMapProvider.overrideWithValue(
              const AsyncValue.data({'cat1': 'Groceries'}),
            ),
            payeeMapProvider.overrideWithValue(
              const AsyncValue.data({'payee1': 'Walmart'}),
            ),
            accountMapProvider.overrideWithValue(
              const AsyncValue.data({'acc1': 'Checking'}),
            ),
            accountsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TransactionsScreen(),
          ),
        ),
      );

      final stopwatch = Stopwatch()..start();
      await tester.pumpAndSettle();
      stopwatch.stop();

      // Ensure it renders in reasonable time (e.g. < 500ms for 1000 items processed and rendered initially)
      // Note: pumpAndSettle waits for animations, but ListView.builder builds lazily.
      // The initial build should be fast.
      // On CI/CD this might vary, but for local verification it's useful.

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
      ); // Generous buffer for test env

      // Scroll performance check (basic)
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);

      final scrollStopwatch = Stopwatch()..start();
      await tester.drag(listFinder, const Offset(0, -5000)); // Fast scroll
      await tester.pump();
      scrollStopwatch.stop();
      expect(scrollStopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}
