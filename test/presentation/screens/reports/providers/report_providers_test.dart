import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/reports/providers/report_providers.dart';
import 'package:mockito/mockito.dart';

import '../../../../mocks/repository_mocks.mocks.dart';

void main() {
  late MockTransactionRepository mockTransactionRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockBudgetRepository mockBudgetRepo;
  late ProviderContainer container;

  setUp(() {
    mockTransactionRepo = MockTransactionRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockBudgetRepo = MockBudgetRepository();

    container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(mockTransactionRepo),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
        budgetRepositoryProvider.overrideWithValue(mockBudgetRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Report Providers Tests', () {
    test('spendingTrendsProvider aggregates monthly spending correctly across years', () async {
      // Arrange
      final start = DateTime(2023, 1, 1);
      final end = DateTime(2024, 12, 31);

      container.read(reportDateRangeProvider.notifier).state = DateTimeRange(start: start, end: end);

      final t1 = Transaction(
        id: '1', accountId: 'a1', date: DateTime(2023, 1, 15), amount: -100,
        categoryId: 'c1', createdAt: DateTime.now()
      );
      final t2 = Transaction(
        id: '2', accountId: 'a1', date: DateTime(2023, 1, 20), amount: -50,
        categoryId: 'c2', createdAt: DateTime.now()
      );
      final t3 = Transaction(
        id: '3', accountId: 'a1', date: DateTime(2024, 5, 10), amount: -200,
        categoryId: 'c1', createdAt: DateTime.now()
      );

      // Income should be ignored
      final t4 = Transaction(
        id: '4', accountId: 'a1', date: DateTime(2023, 6, 1), amount: 1000,
        categoryId: null, createdAt: DateTime.now()
      );

      when(mockTransactionRepo.getTransactionsByDateRange(start, end))
          .thenAnswer((_) async => [t1, t2, t3, t4]);

      // Act
      final trends = await container.read(spendingTrendsProvider.future);

      // Assert
      expect(trends.length, 2);
      expect(trends[DateTime(2023, 1, 1)], 150.0);
      expect(trends[DateTime(2024, 5, 1)], 200.0);
    });

    test('budgetVsActualProvider calculates comparison correctly', () async {
      // Arrange
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);

      container.read(reportDateRangeProvider.notifier).state = DateTimeRange(start: start, end: end);

      final cat1 = Category(id: 'c1', name: 'Food', categoryGroupId: 'g1', createdAt: DateTime.now());
      final cat2 = Category(id: 'c2', name: 'Rent', categoryGroupId: 'g1', createdAt: DateTime.now());

      when(mockCategoryRepo.getAllCategories()).thenAnswer((_) async => [cat1, cat2]);

      // Budget for Jan 2024
      final b1 = Budget(id: 'b1', categoryId: 'c1', month: '2024-01', budgeted: 500, createdAt: DateTime.now());
      final b2 = Budget(id: 'b2', categoryId: 'c2', month: '2024-01', budgeted: 1000, createdAt: DateTime.now());

      when(mockBudgetRepo.getBudgetsForMonth('2024-01')).thenAnswer((_) async => [b1, b2]);

      // Expenses
      // Mock getExpenseSumsByDateRange
      when(mockTransactionRepo.getExpenseSumsByDateRange(start, end)).thenAnswer((_) async => {
        'c1': -450.0, // Spent 450 on Food
        'c2': -1000.0, // Spent 1000 on Rent
      });

      // Act
      final items = await container.read(budgetVsActualProvider.future);

      // Assert
      expect(items.length, 2);

      final foodItem = items.firstWhere((i) => i.categoryName == 'Food');
      expect(foodItem.budgeted, 500.0);
      expect(foodItem.actual, 450.0);

      final rentItem = items.firstWhere((i) => i.categoryName == 'Rent');
      expect(rentItem.budgeted, 1000.0);
      expect(rentItem.actual, 1000.0);
    });
  });
}
