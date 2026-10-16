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
import '../../../../helpers/l10n_override.dart';

void main() {
  late MockTransactionRepository mockTransactionRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockBudgetRepository mockBudgetRepo;
  late MockAccountRepository mockAccountRepo;
  late ProviderContainer container;

  setUp(() {
    mockTransactionRepo = MockTransactionRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockBudgetRepo = MockBudgetRepository();
    mockAccountRepo = MockAccountRepository();

    container = ProviderContainer(
      overrides: [
        englishL10nOverride,
        transactionRepositoryProvider.overrideWithValue(mockTransactionRepo),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepo),
        budgetRepositoryProvider.overrideWithValue(mockBudgetRepo),
        accountRepositoryProvider.overrideWithValue(mockAccountRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Report Providers Tests', () {
    test(
      'spendingTrendsProvider aggregates monthly spending correctly across years',
      () async {
        // Arrange
        final start = DateTime.utc(2023, 1, 1);
        final end = DateTime.utc(2024, 12, 31);

        container.read(reportDateRangeProvider.notifier).state = DateTimeRange(
          start: start,
          end: end,
        );

        final t1 = Transaction(
          id: '1',
          accountId: 'a1',
          date: DateTime.utc(2023, 1, 15),
          amount: -10000,
          categoryId: 'c1',
          createdAt: DateTime.now(),
        );
        final t2 = Transaction(
          id: '2',
          accountId: 'a1',
          date: DateTime.utc(2023, 1, 20),
          amount: -5000,
          categoryId: 'c2',
          createdAt: DateTime.now(),
        );
        final t3 = Transaction(
          id: '3',
          accountId: 'a1',
          date: DateTime.utc(2024, 5, 10),
          amount: -20000,
          categoryId: 'c1',
          createdAt: DateTime.now(),
        );

        // Income should be ignored
        final t4 = Transaction(
          id: '4',
          accountId: 'a1',
          date: DateTime.utc(2023, 6, 1),
          amount: 100000,
          categoryId: null,
          createdAt: DateTime.now(),
        );

        when(
          // Inclusive end day -> half-open query bound.
          mockTransactionRepo.getTransactionsByDateRange(
            start,
            DateTime.utc(2025, 1, 1),
            excludeSplitParents: true,
          ),
        ).thenAnswer((_) async => [t1, t2, t3, t4]);

        // Act
        final trends = await container.read(spendingTrendsProvider.future);

        // Assert
        expect(trends.length, 2);
        expect(trends[DateTime.utc(2023, 1, 1)], 15000);
        expect(trends[DateTime.utc(2024, 5, 1)], 20000);
      },
    );

    test('budgetVsActualProvider calculates comparison correctly', () async {
      // Arrange
      final start = DateTime.utc(2024, 1, 1);
      final end = DateTime.utc(2024, 1, 31);

      container.read(reportDateRangeProvider.notifier).state = DateTimeRange(
        start: start,
        end: end,
      );

      final cat1 = Category(
        id: 'c1',
        name: 'Food',
        categoryGroupId: 'g1',
        createdAt: DateTime.now(),
      );
      final cat2 = Category(
        id: 'c2',
        name: 'Rent',
        categoryGroupId: 'g1',
        createdAt: DateTime.now(),
      );

      when(
        mockCategoryRepo.getAllCategories(),
      ).thenAnswer((_) async => [cat1, cat2]);

      // Budget for Jan 2024
      final b1 = Budget(
        id: 'b1',
        categoryId: 'c1',
        month: '2024-01',
        budgeted: 50000,
        createdAt: DateTime.now(),
      );
      final b2 = Budget(
        id: 'b2',
        categoryId: 'c2',
        month: '2024-01',
        budgeted: 100000,
        createdAt: DateTime.now(),
      );

      when(
        mockBudgetRepo.getBudgetsForMonth('2024-01'),
      ).thenAnswer((_) async => [b1, b2]);

      // Expenses
      // Mock getCategoryActivitySums
      when(
        mockTransactionRepo.getCategoryActivitySums(
          start,
          DateTime.utc(2024, 2, 1),
        ),
      ).thenAnswer(
        (_) async => {
          'c1': -45000, // Spent 450 on Food
          'c2': -100000, // Spent 1000 on Rent
        },
      );

      // Act
      final items = await container.read(budgetVsActualProvider.future);

      // Assert
      expect(items.length, 2);

      final foodItem = items.firstWhere((i) => i.categoryName == 'Food');
      expect(foodItem.budgeted, 50000);
      expect(foodItem.actual, 45000);

      final rentItem = items.firstWhere((i) => i.categoryName == 'Rent');
      expect(rentItem.budgeted, 100000);
      expect(rentItem.actual, 100000);
    });
  });
}

// Net worth (grouped SQL) and refresh tests: report_providers_db_test.dart.
