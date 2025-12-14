import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {
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
        amount: -10.0,
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
            categoryMapProvider.overrideWith(
              (ref) => Stream.value({'cat1': 'Groceries'}),
            ),
            payeeMapProvider.overrideWith(
              (ref) => Stream.value({'payee1': 'Walmart'}),
            ),
            accountMapProvider.overrideWith(
              (ref) => Stream.value({'acc1': 'Checking'}),
            ),
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
      debugPrint(
        'Render time for 1000 items: ${stopwatch.elapsedMilliseconds}ms',
      );

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

      debugPrint('Scroll frame time: ${scrollStopwatch.elapsedMilliseconds}ms');
      expect(
        scrollStopwatch.elapsedMilliseconds,
        lessThan(500),
      ); // Should be fast
    });
  });
}
