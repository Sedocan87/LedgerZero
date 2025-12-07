import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_template_repository.dart';

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
      when(mockTransactionRepo.getIncomeSumByDateRange(any, any))
          .thenAnswer((_) async => 1000.0);
      when(mockBudgetRepo.getTotalBudgetedByMonthRange(any))
          .thenAnswer((_) async => 400.0);

      final tbb = await service.calculateTBB(month);

      expect(tbb, 600.0);
      verify(mockTransactionRepo.getIncomeSumByDateRange(any, any)).called(1);
      verify(mockBudgetRepo.getTotalBudgetedByMonthRange('2023-01')).called(1);
    });
  });

  group('calculateCategoryAvailable', () {
    test('calculates available amount correctly', () async {
      final month = DateTime(2023, 1);
      final categoryId = 'cat1';

      // Total Budgeted (all time)
      when(mockBudgetRepo.getTotalBudgetedByCategoryAndMonthRange(categoryId, '2023-01'))
          .thenAnswer((_) async => 500.0);

      // Total Activity (all time, usually negative)
      when(mockTransactionRepo.getExpenseSumByCategoryAndDateRange(categoryId, any, any))
          .thenAnswer((_) async => -200.0);

      final available = await service.calculateCategoryAvailable(categoryId, month);

      expect(available, 300.0);
    });
  });

  group('setCategoryBudgetedAmount', () {
    test('updates existing budget', () async {
      final month = DateTime(2023, 1);
      final categoryId = 'cat1';
      final existingBudget = Budget(
        id: '1',
        categoryId: categoryId,
        month: '2023-01',
        budgeted: 100.0,
      );

      when(mockBudgetRepo.getBudgetByCategoryAndMonth(categoryId, '2023-01'))
          .thenAnswer((_) async => existingBudget);
      when(mockBudgetRepo.updateBudget(any)).thenAnswer((_) async {});

      await service.setCategoryBudgetedAmount(categoryId, 200.0, month);

      verify(mockBudgetRepo.updateBudget(argThat(
        predicate<Budget>((b) => b.budgeted == 200.0 && b.id == '1')
      ))).called(1);
    });

    test('creates new budget if not exists', () async {
      final month = DateTime(2023, 1);
      final categoryId = 'cat1';

      when(mockBudgetRepo.getBudgetByCategoryAndMonth(categoryId, '2023-01'))
          .thenAnswer((_) async => null);
      when(mockBudgetRepo.createBudget(any)).thenAnswer((_) async {});

      await service.setCategoryBudgetedAmount(categoryId, 200.0, month);

      verify(mockBudgetRepo.createBudget(argThat(
        predicate<Budget>((b) => b.budgeted == 200.0 && b.categoryId == categoryId)
      ))).called(1);
    });
  });

  group('autoAssign', () {
      test('assigns underfunded goal correctly', () async {
          final month = DateTime(2023, 1);
          final categoryId = 'cat1';
          final category = Category(
              id: categoryId,
              name: 'Test',
              goalType: GoalType.monthlyFunding,
              targetAmount: 100.0,
              createdAt: DateTime.now()
          );

          when(mockCategoryRepo.getCategoryById(categoryId))
              .thenAnswer((_) async => category);

          // Assuming setCategoryBudgetedAmount calls create/update, mock that too
          // But autoAssign calls calculateGoalTarget internally, which returns 100.0 for monthlyFunding

          // We need to mock getBudgetByCategoryAndMonth for setCategoryBudgetedAmount
          when(mockBudgetRepo.getBudgetByCategoryAndMonth(categoryId, '2023-01'))
             .thenAnswer((_) async => null); // New budget
          when(mockBudgetRepo.createBudget(any)).thenAnswer((_) async {});


          await service.autoAssign(categoryId, month, AutoAssignRule.underfunded);

          verify(mockBudgetRepo.createBudget(argThat(
              predicate<Budget>((b) => b.budgeted == 100.0)
          ))).called(1);
      });
  });

  group('moveMoney', () {
      test('moves money between categories', () async {
          final month = DateTime(2023, 1);
          final fromCat = 'cat1';
          final toCat = 'cat2';

          final fromBudget = Budget(id: '1', categoryId: fromCat, month: '2023-01', budgeted: 500.0);
          final toBudget = Budget(id: '2', categoryId: toCat, month: '2023-01', budgeted: 100.0);

          when(mockBudgetRepo.getBudgetByCategoryAndMonth(fromCat, '2023-01'))
              .thenAnswer((_) async => fromBudget);
          when(mockBudgetRepo.getBudgetByCategoryAndMonth(toCat, '2023-01'))
              .thenAnswer((_) async => toBudget);

          when(mockBudgetRepo.updateBudget(any)).thenAnswer((_) async {});

          await service.moveMoney(fromCat, toCat, 50.0, month);

          // Verify updates
          verify(mockBudgetRepo.updateBudget(argThat(
              predicate<Budget>((b) => b.categoryId == fromCat && b.budgeted == 450.0)
          ))).called(1);

          verify(mockBudgetRepo.updateBudget(argThat(
              predicate<Budget>((b) => b.categoryId == toCat && b.budgeted == 150.0)
          ))).called(1);
      });
  });
}
