import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/services/analytics_service.dart';
import '../../mocks/repository_mocks.mocks.dart';
import '../../fixtures/model_factories.dart';

void main() {
  late AnalyticsService service;
  late MockAccountRepository mockAccountRepository;
  late MockTransactionRepository mockTransactionRepository;

  setUp(() {
    mockAccountRepository = MockAccountRepository();
    mockTransactionRepository = MockTransactionRepository();
    service = AnalyticsService(
      accountRepository: mockAccountRepository,
      transactionRepository: mockTransactionRepository,
    );
  });

  group('calculateNetWorth', () {
    test('should calculate correct net worth from mixed accounts', () async {
      final accounts = [
        createTestAccount(
            id: '1', type: AccountType.checking, currentBalance: 1000.0),
        createTestAccount(
            id: '2', type: AccountType.savings, currentBalance: 2000.0),
        createTestAccount(
            id: '3', type: AccountType.credit, currentBalance: -500.0),
        createTestAccount(
            id: '4', type: AccountType.cash, currentBalance: 100.0),
      ];

      when(mockAccountRepository.getAllAccounts())
          .thenAnswer((_) async => accounts);

      final result = await service.calculateNetWorth();

      // Assets: 1000 + 2000 + 100 = 3100
      // Liabilities: -500
      // Net Worth: 2600
      expect(result.totalAssets, 3100.0);
      expect(result.totalLiabilities, -500.0);
      expect(result.netWorth, 2600.0);
    });

    test('should handle empty accounts list', () async {
      when(mockAccountRepository.getAllAccounts())
          .thenAnswer((_) async => []);

      final result = await service.calculateNetWorth();

      expect(result.totalAssets, 0.0);
      expect(result.totalLiabilities, 0.0);
      expect(result.netWorth, 0.0);
    });
  });

  group('calculateSpendingStats', () {
    test('should calculate stats correctly for a given range', () async {
      final start = DateTime(2023, 1, 1);
      final end = DateTime(2023, 1, 5); // 5 days

      // Mock expenses: -100 and -200 = -300 total
      final expenseMap = {
        'cat1': -100.0,
        'cat2': -200.0,
      };

      when(mockTransactionRepository.getExpenseSumsByDateRange(start, end))
          .thenAnswer((_) async => expenseMap);

      final result = await service.calculateSpendingStats(start, end);

      expect(result.totalSpending, 300.0);
      expect(result.averageDailySpending, 300.0 / 5); // 60.0
      expect(result.averageWeeklySpending, 300.0 / (5 / 7)); // 420.0
      expect(result.averageMonthlySpending, 300.0 / (5 / 30)); // 1800.0
    });

    test('should handle zero expenses', () async {
      final start = DateTime(2023, 1, 1);
      final end = DateTime(2023, 1, 1); // 1 day

      when(mockTransactionRepository.getExpenseSumsByDateRange(start, end))
          .thenAnswer((_) async => {});

      final result = await service.calculateSpendingStats(start, end);

      expect(result.totalSpending, 0.0);
      expect(result.averageDailySpending, 0.0);
    });
  });

  group('getYearOverYearComparison', () {
    test('should compare two years correctly', () async {
      const currentYear = 2024;
      final startCurrent = DateTime(2024, 1, 1);
      final endCurrent = DateTime(2024, 12, 31, 23, 59, 59);

      final startPrevious = DateTime(2023, 1, 1);
      final endPrevious = DateTime(2023, 12, 31, 23, 59, 59);

      // Current Year: Income 5000, Expense -3000
      when(mockTransactionRepository.getIncomeSumByDateRange(startCurrent, endCurrent))
          .thenAnswer((_) async => 5000.0);
      when(mockTransactionRepository.getExpenseSumsByDateRange(startCurrent, endCurrent))
          .thenAnswer((_) async => {'cat1': -3000.0});

      // Previous Year: Income 4000, Expense -2000
      when(mockTransactionRepository.getIncomeSumByDateRange(startPrevious, endPrevious))
          .thenAnswer((_) async => 4000.0);
      when(mockTransactionRepository.getExpenseSumsByDateRange(startPrevious, endPrevious))
          .thenAnswer((_) async => {'cat1': -2000.0});

      final result = await service.getYearOverYearComparison(currentYear);

      // Verify Current Year
      expect(result.currentYear.year, 2024);
      expect(result.currentYear.income, 5000.0);
      expect(result.currentYear.expense, -3000.0);
      expect(result.currentYear.netSavings, 2000.0);

      // Verify Previous Year
      expect(result.previousYear.year, 2023);
      expect(result.previousYear.income, 4000.0);
      expect(result.previousYear.expense, -2000.0);
      expect(result.previousYear.netSavings, 2000.0);

      // Verify Changes
      // Income Change: (5000 - 4000) / 4000 = 0.25
      expect(result.incomeChangePercentage, 0.25);

      // Expense Change: (-3000 - -2000) / -2000 = -1000 / -2000 = 0.5
      // Wait, expense increased from 2000 to 3000 (magnitude).
      // Logic: (-3000 - (-2000)) / (-2000) = -1000 / -2000 = 0.5.
      // 50% increase in expense (magnitude). Correct.
      expect(result.expenseChangePercentage, 0.5);

      // Savings Change: (2000 - 2000) / 2000 = 0.0
      expect(result.savingsChangePercentage, 0.0);
    });
  });
}
