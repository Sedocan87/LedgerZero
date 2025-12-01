import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late BudgetingService budgetingService;
  late MockTransactionRepository mockTransactionRepository;
  late MockBudgetRepository mockBudgetRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    mockBudgetRepository = MockBudgetRepository();
    mockCategoryRepository = MockCategoryRepository();
    budgetingService = BudgetingService(
      transactionRepository: mockTransactionRepository,
      budgetRepository: mockBudgetRepository,
      categoryRepository: mockCategoryRepository,
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
      // Future budget (should be ignored for TBB up to end of March)
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

    test('should ignore transactions with categoryId (expenses)', () async {
      final targetMonth = DateTime(2025, 3);

      final income = Transaction(
        id: '1',
        accountId: 'acc1',
        date: DateTime(2025, 3, 15),
        amount: 500.0,
        categoryId: null,
      );

      final expense = Transaction(
        id: '2',
        accountId: 'acc1',
        date: DateTime(2025, 3, 16),
        amount: -50.0,
        categoryId: 'cat1',
      );

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [income, expense]);

      final result = await budgetingService.calculateTotalIncomeForMonth(targetMonth);

      expect(result, 500.0);
    });

    test('should ignore transactions with negative amount (outflows without category)', () async {
      final targetMonth = DateTime(2025, 3);

      final income = Transaction(
        id: '1',
        accountId: 'acc1',
        date: DateTime(2025, 3, 15),
        amount: 500.0,
        categoryId: null,
      );

      // Weird case: negative amount but no category (maybe a transfer out or correction)
      // Should not be counted as income.
      final negativeUncategorized = Transaction(
        id: '2',
        accountId: 'acc1',
        date: DateTime(2025, 3, 16),
        amount: -50.0,
        categoryId: null,
      );

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [income, negativeUncategorized]);

      final result = await budgetingService.calculateTotalIncomeForMonth(targetMonth);

      expect(result, 500.0);
    });

    test('should handle leap year February correctly', () async {
      final targetMonth = DateTime(2024, 2); // Leap year

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => []);

      await budgetingService.calculateTotalIncomeForMonth(targetMonth);

      // Verify correct end date for leap year Feb (29th)
      verify(mockTransactionRepository.getTransactionsByDateRange(
        DateTime(2024, 2, 1),
        argThat(predicate((d) => d is DateTime && d.year == 2024 && d.month == 2 && d.day == 29)),
      )).called(1);
    });

    test('should handle month boundaries correctly', () async {
      // Logic relies on repository filtering, but let's ensure we pass correct dates.
      final targetMonth = DateTime(2025, 12); // December

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => []);

      await budgetingService.calculateTotalIncomeForMonth(targetMonth);

      // Verify correct dates for Dec
      verify(mockTransactionRepository.getTransactionsByDateRange(
        DateTime(2025, 12, 1),
        argThat(predicate((d) => d is DateTime && d.year == 2025 && d.month == 12 && d.day == 31)),
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

    test('should return 0.0 if no budgets for the month', () async {
      final targetMonth = DateTime(2025, 4);

      when(mockBudgetRepository.getBudgetsForMonth('2025-04'))
          .thenAnswer((_) async => []);

      final result = await budgetingService.calculateTotalBudgetedForMonth(targetMonth);

      expect(result, 0.0);
    });

    test('should format month string correctly for repository call', () async {
       final targetMonth = DateTime(2025, 1); // January (single digit month)

       when(mockBudgetRepository.getBudgetsForMonth(any))
          .thenAnswer((_) async => []);

       await budgetingService.calculateTotalBudgetedForMonth(targetMonth);

       verify(mockBudgetRepository.getBudgetsForMonth('2025-01')).called(1);
    });
  });

  group('calculateCategoryActivity', () {
    test('should calculate sum of transactions for category in month', () async {
      final targetMonth = DateTime(2025, 3);
      const categoryId = 'cat1';

      final t1 = Transaction(
        id: '1',
        accountId: 'acc1',
        date: DateTime(2025, 3, 5),
        amount: -50.0,
        categoryId: categoryId,
      );
      final t2 = Transaction(
        id: '2',
        accountId: 'acc1',
        date: DateTime(2025, 3, 20),
        amount: -25.0,
        categoryId: categoryId,
      );
      // Transaction for another category
      final t3 = Transaction(
        id: '3',
        accountId: 'acc1',
        date: DateTime(2025, 3, 25),
        amount: -10.0,
        categoryId: 'other_cat',
      );

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [t1, t2, t3]);

      final activity = await budgetingService.calculateCategoryActivity(categoryId, targetMonth);

      expect(activity, -75.0);
    });

    test('should return 0.0 if no transactions for category', () async {
      final targetMonth = DateTime(2025, 3);
      const categoryId = 'cat1';

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => []);

      final activity = await budgetingService.calculateCategoryActivity(categoryId, targetMonth);

      expect(activity, 0.0);
    });
  });

  group('calculateCategoryAvailable', () {
    test('should calculate available correctly (Budgeted + Activity)', () async {
      // Month 1: Budget 100, Activity -50 -> Available 50
      final targetMonth = DateTime(2025, 1);
      const categoryId = 'cat1';

      const budget = Budget(
        id: 'b1',
        categoryId: categoryId,
        month: '2025-01',
        budgeted: 100.0,
      );

      final transaction = Transaction(
        id: 't1',
        accountId: 'acc1',
        date: DateTime(2025, 1, 15),
        amount: -50.0,
        categoryId: categoryId,
      );

      when(mockBudgetRepository.getAllBudgets())
          .thenAnswer((_) async => [budget]);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [transaction]);

      final available = await budgetingService.calculateCategoryAvailable(categoryId, targetMonth);

      expect(available, 50.0);
    });

    test('should handle negative available (Task 85: Overspending)', () async {
      // Month 1: Budget 100, Activity -150 -> Available -50
      final targetMonth = DateTime(2025, 1);
      const categoryId = 'cat1';

      const budget = Budget(
        id: 'b1',
        categoryId: categoryId,
        month: '2025-01',
        budgeted: 100.0,
      );

      final transaction = Transaction(
        id: 't1',
        accountId: 'acc1',
        date: DateTime(2025, 1, 15),
        amount: -150.0,
        categoryId: categoryId,
      );

      when(mockBudgetRepository.getAllBudgets())
          .thenAnswer((_) async => [budget]);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [transaction]);

      final available = await budgetingService.calculateCategoryAvailable(categoryId, targetMonth);

      expect(available, -50.0);
    });

    test('should implement overspending rollover (Task 86)', () async {
      // Month 1: Budget 100, Spend 150 -> Available -50
      // Month 2: Budget 100, Spend 0 -> Available 50 (100 + (-50))
      final targetMonth = DateTime(2025, 2);
      const categoryId = 'cat1';

      const budget1 = Budget(
        id: 'b1',
        categoryId: categoryId,
        month: '2025-01',
        budgeted: 100.0,
      );
      const budget2 = Budget(
        id: 'b2',
        categoryId: categoryId,
        month: '2025-02',
        budgeted: 100.0,
      );

      final transaction1 = Transaction(
        id: 't1',
        accountId: 'acc1',
        date: DateTime(2025, 1, 15),
        amount: -150.0,
        categoryId: categoryId,
      );

      when(mockBudgetRepository.getAllBudgets())
          .thenAnswer((_) async => [budget1, budget2]);

      // Should fetch history from beginning of time
      when(mockTransactionRepository.getTransactionsByDateRange(
        DateTime.fromMillisecondsSinceEpoch(0),
        argThat(predicate((d) => d is DateTime && d.year == 2025 && d.month == 2 && d.day == 28)), // End of Feb
      )).thenAnswer((_) async => [transaction1]);

      final available = await budgetingService.calculateCategoryAvailable(categoryId, targetMonth);

      expect(available, 50.0);
    });

    test('should accumulate positive carryover', () async {
       // Month 1: Budget 100, Spend 50 -> Available 50
       // Month 2: Budget 100, Spend 0 -> Available 150
       final targetMonth = DateTime(2025, 2);
       const categoryId = 'cat1';

       const budget1 = Budget(
         id: 'b1',
         categoryId: categoryId,
         month: '2025-01',
         budgeted: 100.0,
       );
       const budget2 = Budget(
         id: 'b2',
         categoryId: categoryId,
         month: '2025-02',
         budgeted: 100.0,
       );

       final transaction1 = Transaction(
         id: 't1',
         accountId: 'acc1',
         date: DateTime(2025, 1, 15),
         amount: -50.0,
         categoryId: categoryId,
       );

       when(mockBudgetRepository.getAllBudgets())
           .thenAnswer((_) async => [budget1, budget2]);

       when(mockTransactionRepository.getTransactionsByDateRange(any, any))
           .thenAnswer((_) async => [transaction1]);

       final available = await budgetingService.calculateCategoryAvailable(categoryId, targetMonth);

       expect(available, 150.0);
    });
  });

  group('setCategoryBudgetedAmount', () {
    test('should update existing budget if it exists', () async {
      final month = DateTime(2025, 5);
      const categoryId = 'cat1';
      const amount = 500.0;

      const existingBudget = Budget(
        id: 'existing_id',
        categoryId: categoryId,
        month: '2025-05',
        budgeted: 100.0,
      );

      when(mockBudgetRepository.getBudgetByCategoryAndMonth(categoryId, '2025-05'))
          .thenAnswer((_) async => existingBudget);
      when(mockBudgetRepository.updateBudget(any)).thenAnswer((_) async {});

      await budgetingService.setCategoryBudgetedAmount(categoryId, amount, month);

      verify(mockBudgetRepository.updateBudget(argThat(predicate((Budget b) {
        return b.id == 'existing_id' && b.budgeted == 500.0;
      })))).called(1);
      verifyNever(mockBudgetRepository.createBudget(any));
    });

    test('should create new budget if it does not exist', () async {
      final month = DateTime(2025, 5);
      const categoryId = 'cat1';
      const amount = 500.0;

      when(mockBudgetRepository.getBudgetByCategoryAndMonth(categoryId, '2025-05'))
          .thenAnswer((_) async => null);
      when(mockBudgetRepository.createBudget(any)).thenAnswer((_) async {});

      await budgetingService.setCategoryBudgetedAmount(categoryId, amount, month);

      verify(mockBudgetRepository.createBudget(argThat(predicate((Budget b) {
        return b.categoryId == categoryId && b.month == '2025-05' && b.budgeted == 500.0;
      })))).called(1);
    });
  });

  group('moveMoney', () {
    test('should move money between two existing budgets', () async {
      final month = DateTime(2025, 5);
      const fromCatId = 'cat1';
      const toCatId = 'cat2';
      const amount = 50.0;

      const fromBudget = Budget(
        id: 'b1',
        categoryId: fromCatId,
        month: '2025-05',
        budgeted: 100.0,
      );
      const toBudget = Budget(
        id: 'b2',
        categoryId: toCatId,
        month: '2025-05',
        budgeted: 200.0,
      );

      when(mockBudgetRepository.getBudgetByCategoryAndMonth(fromCatId, '2025-05'))
          .thenAnswer((_) async => fromBudget);
      when(mockBudgetRepository.getBudgetByCategoryAndMonth(toCatId, '2025-05'))
          .thenAnswer((_) async => toBudget);
      when(mockBudgetRepository.updateBudget(any)).thenAnswer((_) async {});

      await budgetingService.moveMoney(fromCatId, toCatId, amount, month);

      // Verify updates
      verify(mockBudgetRepository.updateBudget(argThat(predicate((Budget b) {
        return b.id == 'b1' && b.budgeted == 50.0; // 100 - 50
      })))).called(1);

      verify(mockBudgetRepository.updateBudget(argThat(predicate((Budget b) {
        return b.id == 'b2' && b.budgeted == 250.0; // 200 + 50
      })))).called(1);
    });

    test('should create budgets if they do not exist during move', () async {
      final month = DateTime(2025, 5);
      const fromCatId = 'cat1';
      const toCatId = 'cat2';
      const amount = 50.0;

      when(mockBudgetRepository.getBudgetByCategoryAndMonth(fromCatId, '2025-05'))
          .thenAnswer((_) async => null);
      when(mockBudgetRepository.getBudgetByCategoryAndMonth(toCatId, '2025-05'))
          .thenAnswer((_) async => null);

      // Capture created budget to return it for update step?
      // Actually, my implementation creates it first, then updates it.
      // But mock repository.createBudget just returns void.
      // The service implementation retrieves it again? No, it uses the created object.
      // Wait, let's check implementation of moveMoney again.

      // Implementation:
      // if (fromBudget == null) { create; }
      // But `create` doesn't return the budget.
      // The implementation creates a Budget object, calls createBudget, and then uses that object locally.
      // So mocking createBudget is enough.

      when(mockBudgetRepository.createBudget(any)).thenAnswer((_) async {});
      when(mockBudgetRepository.updateBudget(any)).thenAnswer((_) async {});

      await budgetingService.moveMoney(fromCatId, toCatId, amount, month);

      // Should create both
      verify(mockBudgetRepository.createBudget(argThat(predicate((Budget b) {
         return b.categoryId == fromCatId && b.budgeted == 0.0;
      })))).called(1);
       verify(mockBudgetRepository.createBudget(argThat(predicate((Budget b) {
         return b.categoryId == toCatId && b.budgeted == 0.0;
      })))).called(1);

      // And then update both
      verify(mockBudgetRepository.updateBudget(argThat(predicate((Budget b) {
        // Created with 0, subtracted 50 -> -50
        return b.categoryId == fromCatId && b.budgeted == -50.0;
      })))).called(1);

      verify(mockBudgetRepository.updateBudget(argThat(predicate((Budget b) {
        // Created with 0, added 50 -> 50
        return b.categoryId == toCatId && b.budgeted == 50.0;
      })))).called(1);
    });
  });

  group('initializeMonthBudgets', () {
    test('should create budgets for all categories if they do not exist', () async {
      final month = DateTime(2025, 6);
      const cat1 = Category(id: 'c1', name: 'Cat1', isHidden: false);
      const cat2 = Category(id: 'c2', name: 'Cat2', isHidden: false);

      when(mockCategoryRepository.getAllCategories())
          .thenAnswer((_) async => [cat1, cat2]);

      // c1 exists
      when(mockBudgetRepository.getBudgetByCategoryAndMonth('c1', '2025-06'))
          .thenAnswer((_) async => const Budget(id: 'b1', categoryId: 'c1', month: '2025-06'));

      // c2 does not exist
      when(mockBudgetRepository.getBudgetByCategoryAndMonth('c2', '2025-06'))
          .thenAnswer((_) async => null);

      when(mockBudgetRepository.createBudget(any)).thenAnswer((_) async {});

      await budgetingService.initializeMonthBudgets(month);

      // Should only create for c2
      verify(mockBudgetRepository.createBudget(argThat(predicate((Budget b) {
        return b.categoryId == 'c2' && b.month == '2025-06' && b.budgeted == 0.0;
      })))).called(1);

      // Should not create for c1 (it exists)
       verifyNever(mockBudgetRepository.createBudget(argThat(predicate((Budget b) {
        return b.categoryId == 'c1';
      }))));
    });
  });
}
