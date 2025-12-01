import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';

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

  // ... (Existing tests: calculateTBB, etc.)
  group('calculateTBB', () {
    test('should calculate TBB correctly with income and budgeted amounts', () async {
      final targetMonth = DateTime(2025, 3);
      final income1 = Transaction(id: '1', accountId: 'acc1', date: DateTime(2025, 1, 15), amount: 1000.0, categoryId: null);
      final income2 = Transaction(id: '2', accountId: 'acc1', date: DateTime(2025, 3, 10), amount: 500.0, categoryId: null);
      final expense1 = Transaction(id: '3', accountId: 'acc1', date: DateTime(2025, 2, 20), amount: -50.0, categoryId: 'cat1');
      const budget1 = Budget(id: 'b1', categoryId: 'cat1', month: '2025-01', budgeted: 200.0);
      const budget2 = Budget(id: 'b2', categoryId: 'cat2', month: '2025-03', budgeted: 300.0);
      const budgetFuture = Budget(id: 'b3', categoryId: 'cat1', month: '2025-04', budgeted: 100.0);

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [income1, income2, expense1]);
      when(mockBudgetRepository.getAllBudgets())
          .thenAnswer((_) async => [budget1, budget2, budgetFuture]);

      final tbb = await budgetingService.calculateTBB(targetMonth);
      expect(tbb, 1000.0);
    });

    test('should return 0.0 if no income and no budgets', () async {
      final targetMonth = DateTime(2025, 3);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any)).thenAnswer((_) async => []);
      when(mockBudgetRepository.getAllBudgets()).thenAnswer((_) async => []);
      final tbb = await budgetingService.calculateTBB(targetMonth);
      expect(tbb, 0.0);
    });
  });

  group('calculateTotalIncomeForMonth', () {
    test('should calculate income for specific month only', () async {
      final targetMonth = DateTime(2025, 3);
      final income = Transaction(id: '1', accountId: 'acc1', date: DateTime(2025, 3, 15), amount: 500.0, categoryId: null);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any)).thenAnswer((_) async => [income]);
      final result = await budgetingService.calculateTotalIncomeForMonth(targetMonth);
      expect(result, 500.0);
    });
  });

  group('calculateTotalBudgetedForMonth', () {
    test('should calculate budgeted amount for specific month', () async {
      final targetMonth = DateTime(2025, 3);
      const budget1 = Budget(id: 'b1', categoryId: 'cat1', month: '2025-03', budgeted: 100.0);
      const budget2 = Budget(id: 'b2', categoryId: 'cat2', month: '2025-03', budgeted: 200.0);
      when(mockBudgetRepository.getBudgetsForMonth('2025-03')).thenAnswer((_) async => [budget1, budget2]);
      final result = await budgetingService.calculateTotalBudgetedForMonth(targetMonth);
      expect(result, 300.0);
    });
  });

  group('calculateCategoryActivity', () {
    test('should calculate sum of transactions for category in month', () async {
      final targetMonth = DateTime(2025, 3);
      const categoryId = 'cat1';
      final t1 = Transaction(id: '1', accountId: 'acc1', date: DateTime(2025, 3, 5), amount: -50.0, categoryId: categoryId);
      final t2 = Transaction(id: '2', accountId: 'acc1', date: DateTime(2025, 3, 20), amount: -25.0, categoryId: categoryId);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any)).thenAnswer((_) async => [t1, t2]);
      final activity = await budgetingService.calculateCategoryActivity(categoryId, targetMonth);
      expect(activity, -75.0);
    });
  });

  group('calculateCategoryAvailable', () {
    test('should calculate available correctly (Budgeted + Activity)', () async {
      final targetMonth = DateTime(2025, 1);
      const categoryId = 'cat1';
      const budget = Budget(id: 'b1', categoryId: categoryId, month: '2025-01', budgeted: 100.0);
      final transaction = Transaction(id: 't1', accountId: 'acc1', date: DateTime(2025, 1, 15), amount: -50.0, categoryId: categoryId);
      when(mockBudgetRepository.getAllBudgets()).thenAnswer((_) async => [budget]);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any)).thenAnswer((_) async => [transaction]);
      final available = await budgetingService.calculateCategoryAvailable(categoryId, targetMonth);
      expect(available, 50.0);
    });
  });

  group('Goal Calculations', () {
    test('should calculate monthly funding target', () async {
      const category = Category(id: 'c1', name: 'Savings', goalType: GoalType.monthlyFunding, targetAmount: 200.0);
      final month = DateTime(2025, 3);

      final target = await budgetingService.calculateGoalTarget(category, month);
      expect(target, 200.0);
    });

    test('should calculate target balance gap', () async {
      const category = Category(id: 'c1', name: 'Car', goalType: GoalType.targetBalance, targetAmount: 1000.0);
      final month = DateTime(2025, 3);

      // Prev Month: Feb 2025. Budget: 800. Spend: 0. Available: 800.
      const prevBudget = Budget(id: 'b1', categoryId: 'c1', month: '2025-02', budgeted: 800.0);

      when(mockBudgetRepository.getAllBudgets()).thenAnswer((_) async => [prevBudget]);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any)).thenAnswer((_) async => []);

      final target = await budgetingService.calculateGoalTarget(category, month);
      expect(target, 200.0); // 1000 - 800
    });

    test('should calculate target balance by date', () async {
      // Goal: 1200 by Dec 2025.
      // Current: Jan 2025. 12 months.
      // Prior available: 0.
      final targetDate = DateTime(2025, 12, 31);
      final category = Category(id: 'c1', name: 'Xmas', goalType: GoalType.targetBalanceByDate, targetAmount: 1200.0, targetDate: targetDate);
      final month = DateTime(2025, 1);

      when(mockBudgetRepository.getAllBudgets()).thenAnswer((_) async => []);
      when(mockTransactionRepository.getTransactionsByDateRange(any, any)).thenAnswer((_) async => []);

      final target = await budgetingService.calculateGoalTarget(category, month);
      expect(target, 100.0); // 1200 / 12
    });

    test('should calculate funded percentage', () async {
      // Goal: 200 monthly. Budgeted: 100. Percentage: 0.5.
      const category = Category(id: 'c1', name: 'Savings', goalType: GoalType.monthlyFunding, targetAmount: 200.0);
      final month = DateTime(2025, 3);
      const budget = Budget(id: 'b1', categoryId: 'c1', month: '2025-03', budgeted: 100.0);

      when(mockBudgetRepository.getBudgetByCategoryAndMonth('c1', '2025-03')).thenAnswer((_) async => budget);

      final percentage = await budgetingService.calculateFundedPercentage(category, month);
      expect(percentage, 0.5);
    });
  });

  group('History', () {
    test('should calculate average spent', () async {
      // Last 3 months (Dec, Jan, Feb) relative to Mar.
      // Dec: -100. Jan: -200. Feb: -300. Total -600. Avg 200.
      final referenceMonth = DateTime(2025, 3);
      const categoryId = 'c1';

      final t1 = Transaction(id: '1', accountId: 'a1', date: DateTime(2024, 12, 10), amount: -100.0, categoryId: categoryId);
      final t2 = Transaction(id: '2', accountId: 'a1', date: DateTime(2025, 1, 10), amount: -200.0, categoryId: categoryId);
      final t3 = Transaction(id: '3', accountId: 'a1', date: DateTime(2025, 2, 10), amount: -300.0, categoryId: categoryId);

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [t1, t2, t3]);

      final avg = await budgetingService.getAverageSpent(categoryId, 3, referenceMonth);
      expect(avg, 200.0);
    });

    test('should get last month spent', () async {
      final currentMonth = DateTime(2025, 3);
      const categoryId = 'c1';
      final t1 = Transaction(id: '1', accountId: 'a1', date: DateTime(2025, 2, 10), amount: -150.0, categoryId: categoryId);

      when(mockTransactionRepository.getTransactionsByDateRange(any, any))
          .thenAnswer((_) async => [t1]);

      final spent = await budgetingService.getLastMonthSpent(categoryId, currentMonth);
      expect(spent, 150.0);
    });
  });

  group('Auto Assign', () {
    test('should auto assign underfunded amount', () async {
      final month = DateTime(2025, 3);
      const categoryId = 'c1';
      const category = Category(id: categoryId, name: 'C1', goalType: GoalType.monthlyFunding, targetAmount: 300.0);

      when(mockCategoryRepository.getCategoryById(categoryId)).thenAnswer((_) async => category);
      when(mockBudgetRepository.getBudgetByCategoryAndMonth(categoryId, '2025-03')).thenAnswer((_) async => null);
      when(mockBudgetRepository.createBudget(any)).thenAnswer((_) async {});

      await budgetingService.autoAssign(categoryId, month, AutoAssignRule.underfunded);

      verify(mockBudgetRepository.createBudget(argThat(predicate((Budget b) {
        return b.budgeted == 300.0;
      })))).called(1);
    });
  });
}
