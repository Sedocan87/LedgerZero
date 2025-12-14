import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';

// Import the generated mocks
import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late BudgetingService service;
  late MockTransactionRepository mockTransactionRepo;
  late MockBudgetRepository mockBudgetRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockBudgetTemplateRepository mockBudgetTemplateRepo;

  setUp(() {
    mockTransactionRepo = MockTransactionRepository();
    mockBudgetRepo = MockBudgetRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockBudgetTemplateRepo = MockBudgetTemplateRepository();

    service = BudgetingService(
      transactionRepository: mockTransactionRepo,
      budgetRepository: mockBudgetRepo,
      categoryRepository: mockCategoryRepo,
      budgetTemplateRepository: mockBudgetTemplateRepo,
    );
  });

  group('calculateTBB', () {
    test('calculates TBB correctly', () async {
      final month = DateTime(2023, 1);

      // Setup mocks
      when(
        mockTransactionRepo.getIncomeSumByDateRange(any, any),
      ).thenAnswer((_) async => 1000.0);
      when(
        mockBudgetRepo.getTotalBudgetedByMonthRange(any),
      ).thenAnswer((_) async => 400.0);

      final tbb = await service.calculateTBB(month);

      expect(tbb, 600.0);
      verify(mockTransactionRepo.getIncomeSumByDateRange(any, any)).called(1);
      verify(mockBudgetRepo.getTotalBudgetedByMonthRange('2023-01')).called(1);
    });
  });

  group('calculateCategoryAvailable', () {
    test('calculates available amount correctly', () async {
      final month = DateTime(2023, 1);
      const categoryId = 'cat1';

      // Total Budgeted (all time)
      when(
        mockBudgetRepo.getTotalBudgetedByCategoryAndMonthRange(
          categoryId,
          '2023-01',
        ),
      ).thenAnswer((_) async => 500.0);

      // Total Activity (all time, usually negative)
      when(
        mockTransactionRepo.getExpenseSumByCategoryAndDateRange(
          categoryId,
          any,
          any,
        ),
      ).thenAnswer((_) async => -200.0);

      final available = await service.calculateCategoryAvailable(
        categoryId,
        month,
      );

      expect(available, 300.0);
    });

    test('calculates negative available amount (overspending)', () async {
      final month = DateTime(2023, 1);
      const categoryId = 'cat1';

      // Total Budgeted (all time)
      when(
        mockBudgetRepo.getTotalBudgetedByCategoryAndMonthRange(
          categoryId,
          '2023-01',
        ),
      ).thenAnswer((_) async => 500.0);

      // Total Activity (all time, usually negative) - Overspent by 100
      when(
        mockTransactionRepo.getExpenseSumByCategoryAndDateRange(
          categoryId,
          any,
          any,
        ),
      ).thenAnswer((_) async => -600.0);

      final available = await service.calculateCategoryAvailable(
        categoryId,
        month,
      );

      expect(available, -100.0);
    });
  });

  group('setCategoryBudgetedAmount', () {
    test('updates existing budget', () async {
      final month = DateTime(2023, 1);
      const categoryId = 'cat1';
      const existingBudget = Budget(
        id: '1',
        categoryId: categoryId,
        month: '2023-01',
        budgeted: 100.0,
      );

      when(
        mockBudgetRepo.getBudgetByCategoryAndMonth(categoryId, '2023-01'),
      ).thenAnswer((_) async => existingBudget);
      when(mockBudgetRepo.updateBudget(any)).thenAnswer((_) async {});

      await service.setCategoryBudgetedAmount(categoryId, 200.0, month);

      verify(
        mockBudgetRepo.updateBudget(
          argThat(predicate<Budget>((b) => b.budgeted == 200.0 && b.id == '1')),
        ),
      ).called(1);
    });

    test('creates new budget if not exists', () async {
      final month = DateTime(2023, 1);
      const categoryId = 'cat1';

      when(
        mockBudgetRepo.getBudgetByCategoryAndMonth(categoryId, '2023-01'),
      ).thenAnswer((_) async => null);
      when(mockBudgetRepo.createBudget(any)).thenAnswer((_) async {});

      await service.setCategoryBudgetedAmount(categoryId, 200.0, month);

      verify(
        mockBudgetRepo.createBudget(
          argThat(
            predicate<Budget>(
              (b) => b.budgeted == 200.0 && b.categoryId == categoryId,
            ),
          ),
        ),
      ).called(1);
    });
  });

  group('autoAssign', () {
    test('assigns underfunded goal correctly', () async {
      final month = DateTime(2023, 1);
      const categoryId = 'cat1';
      final category = Category(
        id: categoryId,
        name: 'Test',
        goalType: GoalType.monthlyFunding,
        targetAmount: 100.0,
        createdAt: DateTime.now(),
      );

      when(
        mockCategoryRepo.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      // Assuming setCategoryBudgetedAmount calls create/update, mock that too
      // But autoAssign calls calculateGoalTarget internally, which returns 100.0 for monthlyFunding

      // We need to mock getBudgetByCategoryAndMonth for setCategoryBudgetedAmount
      when(
        mockBudgetRepo.getBudgetByCategoryAndMonth(categoryId, '2023-01'),
      ).thenAnswer((_) async => null); // New budget
      when(mockBudgetRepo.createBudget(any)).thenAnswer((_) async {});

      await service.autoAssign(categoryId, month, AutoAssignRule.underfunded);

      verify(
        mockBudgetRepo.createBudget(
          argThat(predicate<Budget>((b) => b.budgeted == 100.0)),
        ),
      ).called(1);
    });
  });

  group('moveMoney', () {
    test('moves money between categories', () async {
      final month = DateTime(2023, 1);
      const fromCat = 'cat1';
      const toCat = 'cat2';

      const fromBudget = Budget(
        id: '1',
        categoryId: fromCat,
        month: '2023-01',
        budgeted: 500.0,
      );
      const toBudget = Budget(
        id: '2',
        categoryId: toCat,
        month: '2023-01',
        budgeted: 100.0,
      );

      when(
        mockBudgetRepo.getBudgetByCategoryAndMonth(fromCat, '2023-01'),
      ).thenAnswer((_) async => fromBudget);
      when(
        mockBudgetRepo.getBudgetByCategoryAndMonth(toCat, '2023-01'),
      ).thenAnswer((_) async => toBudget);

      when(mockBudgetRepo.updateBudget(any)).thenAnswer((_) async {});

      await service.moveMoney(fromCat, toCat, 50.0, month);

      // Verify updates
      verify(
        mockBudgetRepo.updateBudget(
          argThat(
            predicate<Budget>(
              (b) => b.categoryId == fromCat && b.budgeted == 450.0,
            ),
          ),
        ),
      ).called(1);

      verify(
        mockBudgetRepo.updateBudget(
          argThat(
            predicate<Budget>(
              (b) => b.categoryId == toCat && b.budgeted == 150.0,
            ),
          ),
        ),
      ).called(1);
    });
  });

  group('calculateTotalIncomeForMonth', () {
    test('calculates total income for specific month', () async {
      final month = DateTime(2023, 3);
      when(
        mockTransactionRepo.getIncomeSumByDateRange(any, any),
      ).thenAnswer((_) async => 2500.0);

      final income = await service.calculateTotalIncomeForMonth(month);

      expect(income, 2500.0);
      verify(
        mockTransactionRepo.getIncomeSumByDateRange(
          DateTime(2023, 3, 1),
          argThat(
            predicate<DateTime>(
              (d) => d.year == 2023 && d.month == 3 && d.day == 31,
            ),
          ),
        ),
      ).called(1);
    });
  });

  group('calculateTotalSpendingForMonth', () {
    test(
      'calculates total spending (negative transactions) for specific month',
      () async {
        final month = DateTime(2023, 3);
        final transactions = [
          Transaction(
            id: '1',
            accountId: 'a',
            date: DateTime(2023, 3, 1),
            amount: -50.0,
          ),
          Transaction(
            id: '2',
            accountId: 'a',
            date: DateTime(2023, 3, 2),
            amount: -25.0,
          ),
          Transaction(
            id: '3',
            accountId: 'a',
            date: DateTime(2023, 3, 3),
            amount: 100.0,
          ), // Income, should be ignored
        ];

        when(
          mockTransactionRepo.getTransactionsByDateRange(any, any),
        ).thenAnswer((_) async => transactions);

        final spending = await service.calculateTotalSpendingForMonth(month);

        expect(spending, -75.0);
      },
    );
  });

  group('calculateCategoryActivity', () {
    test('calculates category activity correctly', () async {
      final month = DateTime(2023, 4);
      const categoryId = 'cat_groceries';

      when(
        mockTransactionRepo.getExpenseSumByCategoryAndDateRange(
          categoryId,
          any,
          any,
        ),
      ).thenAnswer((_) async => -450.0);

      final activity = await service.calculateCategoryActivity(
        categoryId,
        month,
      );

      expect(activity, -450.0);
    });
  });

  group('createBudgetSnapshot', () {
    test('snapshots budget state for all categories', () async {
      final month = DateTime(2023, 5);
      final categories = [
        Category(id: 'c1', name: 'Cat 1', createdAt: DateTime.now()),
        Category(id: 'c2', name: 'Cat 2', createdAt: DateTime.now()),
      ];

      when(
        mockCategoryRepo.getAllCategories(),
      ).thenAnswer((_) async => categories);

      // Mocks for calculations
      when(
        mockTransactionRepo.getExpenseSumByCategoryAndDateRange(any, any, any),
      ).thenAnswer((_) async => -100.0); // Activity
      when(
        mockBudgetRepo.getTotalBudgetedByCategoryAndMonthRange(any, any),
      ).thenAnswer((_) async => 200.0); // Budgeted so available = 100.0

      when(
        mockBudgetRepo.getBudgetByCategoryAndMonth(any, any),
      ).thenAnswer((_) async => null); // No existing budget
      when(mockBudgetRepo.createBudget(any)).thenAnswer((_) async {});

      await service.createBudgetSnapshot(month);

      // Verify two budgets created with correct snapshots
      verify(
        mockBudgetRepo.createBudget(
          argThat(
            predicate<Budget>(
              (b) => b.activity == -100.0 && b.available == 100.0,
            ),
          ),
        ),
      ).called(2);
    });
  });
}
