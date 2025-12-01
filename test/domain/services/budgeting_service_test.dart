import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late BudgetingService budgetingService;
  late MockTransactionRepository mockTransactionRepository;
  late MockBudgetRepository mockBudgetRepository;

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    mockBudgetRepository = MockBudgetRepository();
    budgetingService = BudgetingService(
      transactionRepository: mockTransactionRepository,
      budgetRepository: mockBudgetRepository,
    );
  });

  group('calculateTBB', () {
    test('should calculate TBB correctly with income and budgeted amounts', () async {
      final targetMonth = DateTime(2025, 3); // March 2025

      // Income transactions (categoryId is null, amount > 0)
      final income1 = Transaction(
        id: '1',
        accountId: 'acc1',
        date: DateTime(2025, 1, 15),
        amount: 1000.0,
        categoryId: null,
      );
      final income2 = Transaction(
        id: '2',
        accountId: 'acc1',
        date: DateTime(2025, 3, 10),
        amount: 500.0,
        categoryId: null,
      );
      // Future income (should be ignored for March TBB?)
      // Wait, getTransactionsByDateRange is called with end of March.
      // So checking logic inside service.

      // Expense transaction (should be ignored for Income calculation)
      final expense1 = Transaction(
        id: '3',
        accountId: 'acc1',
        date: DateTime(2025, 2, 20),
        amount: -50.0,
        categoryId: 'cat1',
      );

      // Budgets
      const budget1 = Budget(
        id: 'b1',
        categoryId: 'cat1',
        month: '2025-01',
        budgeted: 200.0,
      );
      const budget2 = Budget(
        id: 'b2',
        categoryId: 'cat2',
        month: '2025-03',
        budgeted: 300.0,
      );
      // Future budget (should be ignored)
      const budgetFuture = Budget(
        id: 'b3',
        categoryId: 'cat1',
        month: '2025-04',
        budgeted: 100.0,
      );

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [income1, income2, expense1]);

      when(mockBudgetRepository.getAllBudgets())
          .thenAnswer((_) async => [budget1, budget2, budgetFuture]);

      final tbb = await budgetingService.calculateTBB(targetMonth);

      // Expected:
      // Total Income = 1000 + 500 = 1500
      // Total Budgeted = 200 (Jan) + 300 (Mar) = 500. (Apr is ignored)
      // TBB = 1500 - 500 = 1000.
      expect(tbb, 1000.0);
    });

    test('should return 0.0 if no income and no budgets', () async {
      final targetMonth = DateTime(2025, 3);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => []);
      when(mockBudgetRepository.getAllBudgets())
          .thenAnswer((_) async => []);

      final tbb = await budgetingService.calculateTBB(targetMonth);
      expect(tbb, 0.0);
    });
  });

  group('calculateTotalIncomeForMonth', () {
    test('should calculate income for specific month only', () async {
      final targetMonth = DateTime(2025, 3);

      final income = Transaction(
        id: '1',
        accountId: 'acc1',
        date: DateTime(2025, 3, 15),
        amount: 500.0,
        categoryId: null,
      );

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [income]);

      final result = await budgetingService.calculateTotalIncomeForMonth(targetMonth);

      expect(result, 500.0);
      verify(mockTransactionRepository.getTransactionsByDateRange(
        DateTime(2025, 3, 1),
        argThat(predicate((d) => d is DateTime && d.year == 2025 && d.month == 3 && d.day == 31)),
      )).called(1);
    });
  });

  group('calculateTotalBudgetedForMonth', () {
    test('should calculate budgeted amount for specific month', () async {
      final targetMonth = DateTime(2025, 3);

      const budget1 = Budget(
        id: 'b1',
        categoryId: 'cat1',
        month: '2025-03',
        budgeted: 100.0,
      );
       const budget2 = Budget(
        id: 'b2',
        categoryId: 'cat2',
        month: '2025-03',
        budgeted: 200.0,
      );

      when(mockBudgetRepository.getBudgetsForMonth('2025-03'))
          .thenAnswer((_) async => [budget1, budget2]);

      final result = await budgetingService.calculateTotalBudgetedForMonth(targetMonth);

      expect(result, 300.0);
    });
  });
}
