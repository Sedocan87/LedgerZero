import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:mockito/mockito.dart';

import '../../../../mocks/repository_mocks.mocks.dart';

void main() {
  late MockTransactionRepository mockTransactionRepository;
  late MockCategoryRepository mockCategoryRepository;
  late MockAccountRepository mockAccountRepository;

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    mockCategoryRepository = MockCategoryRepository();
    mockAccountRepository = MockAccountRepository();
  });

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(mockTransactionRepository),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        accountRepositoryProvider.overrideWithValue(mockAccountRepository),
      ],
    );
  }

  group('Report Providers', () {
    test('spendingByCategoryProvider returns correct data', () async {
      final container = createContainer();
      final range = container.read(reportDateRangeProvider);

      when(mockTransactionRepository.getExpenseSumsByDateRange(range.start, range.end))
          .thenAnswer((_) async => {'cat1': 100.0, 'cat2': 50.0});

      when(mockCategoryRepository.getAllCategories()).thenAnswer((_) async => [
            const Category(id: 'cat1', name: 'Food', categoryGroupId: 'g1', color: 0, icon: 'icon'),
            const Category(id: 'cat2', name: 'Transport', categoryGroupId: 'g1', color: 0, icon: 'icon'),
          ]);

      final result = await container.read(spendingByCategoryProvider.future);

      expect(result, {'Food': 100.0, 'Transport': 50.0});
    });

    test('incomeVsExpenseHistoryProvider returns correct series', () async {
      final container = createContainer();
      final range = container.read(reportDateRangeProvider);

      final t1 = Transaction(
        id: 't1',
        accountId: 'a1',
        date: DateTime(range.start.year, 1, 15),
        amount: 1000,
        categoryId: null, // Income
        cleared: TransactionClearStatus.cleared,
        approved: true,
      );
      final t2 = Transaction(
        id: 't2',
        accountId: 'a1',
        date: DateTime(range.start.year, 1, 20),
        amount: -200,
        categoryId: 'cat1', // Expense
        cleared: TransactionClearStatus.cleared,
        approved: true,
      );

      when(mockTransactionRepository.getTransactionsByDateRange(range.start, range.end))
          .thenAnswer((_) async => [t1, t2]);

      final result = await container.read(incomeVsExpenseHistoryProvider.future);

      expect(result.length, 2);
      expect(result[0].name, 'Income');
      expect(result[0].points.first.value, 1000.0);
      expect(result[1].name, 'Expenses');
      expect(result[1].points.first.value, 200.0);
    });

    test('netWorthHistoryProvider calculates correctly', () async {
      final container = createContainer();
      final range = container.read(reportDateRangeProvider);

      // Account with starting balance 1000
      const account = Account(
        id: 'a1',
        name: 'Checking',
        type: AccountType.checking,
        startingBalance: 1000.0,
      );

      when(mockAccountRepository.getAllAccounts()).thenAnswer((_) async => [account]);

      // Transaction before range: -100 (Balance becomes 900)
      final tBefore = Transaction(
        id: 't0',
        accountId: 'a1',
        date: range.start.subtract(const Duration(days: 10)),
        amount: -100,
        cleared: TransactionClearStatus.cleared,
        approved: true,
      );

      // Transaction in range: -50 (Balance becomes 850)
      final tIn = Transaction(
        id: 't1',
        accountId: 'a1',
        date: range.start.add(const Duration(days: 5)),
        amount: -50,
        cleared: TransactionClearStatus.cleared,
        approved: true,
      );

      when(mockTransactionRepository.getAllTransactions())
          .thenAnswer((_) async => [tBefore, tIn]);

      final result = await container.read(netWorthHistoryProvider.future);

      expect(result.length, 1);
      final points = result.first.points;

      // Initial point at range start should be 900 (1000 - 100)
      expect(points.first.date, range.start);
      expect(points.first.value, 900.0);

      // Point at tIn date should be 850 (900 - 50)
      // Note: My implementation adds a point for tIn.date
      expect(points[1].value, 850.0);

      // Point at end of range should be 850
      expect(points.last.date, range.end);
      expect(points.last.value, 850.0);
    });
  });
}
