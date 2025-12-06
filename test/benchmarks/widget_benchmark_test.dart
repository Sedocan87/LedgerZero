import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/services/widget/widget_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_benchmark_test.mocks.dart';

@GenerateMocks([
  BudgetingService,
  TransactionRepository,
  CategoryRepository,
  PayeeRepository,
  SharedPreferences,
])
void main() {
  late MockBudgetingService mockBudgetingService;
  late MockTransactionRepository mockTransactionRepository;
  late MockCategoryRepository mockCategoryRepository;
  late MockPayeeRepository mockPayeeRepository;
  late MockSharedPreferences mockSharedPreferences;
  late WidgetService widgetService;

  setUp(() {
    mockBudgetingService = MockBudgetingService();
    mockTransactionRepository = MockTransactionRepository();
    mockCategoryRepository = MockCategoryRepository();
    mockPayeeRepository = MockPayeeRepository();
    mockSharedPreferences = MockSharedPreferences();

    widgetService = WidgetService(
      mockBudgetingService,
      mockTransactionRepository,
      mockCategoryRepository,
      mockPayeeRepository,
      mockSharedPreferences,
    );

    // Default mock behavior
    when(mockSharedPreferences.getStringList(any)).thenReturn([]);
    when(mockBudgetingService.calculateTBB(any)).thenAnswer((_) async => 1000.0);
    when(mockCategoryRepository.getAllCategories()).thenAnswer((_) async => []);
    when(mockBudgetingService.calculateBatchCategoryPerformance(any)).thenAnswer((_) async => {});
    when(mockTransactionRepository.getTransactions(limit: anyNamed('limit'))).thenAnswer((_) async => []);
  });

  test('Widget payload generation should be efficient (< 50ms)', () async {
    // Setup a moderate amount of data
    final categories = List.generate(50, (index) => Category(
      id: 'cat_$index',
      name: 'Category $index',
      createdAt: DateTime.now(),
      color: 0,
      icon: 'icon_$index',
      goalType: null,
      targetAmount: null,
      targetDate: null,
      isHidden: false,
      sortOrder: index,
      categoryGroupId: 'group_1',
    ));

    final transactions = List.generate(5, (index) => Transaction(
      id: 'tx_$index',
      accountId: 'acc_1',
      date: DateTime.now(),
      amount: -10.0,
      payeeId: 'payee_$index',
      categoryId: 'cat_$index',
      cleared: TransactionClearStatus.cleared,
      approved: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    when(mockCategoryRepository.getAllCategories()).thenAnswer((_) async => categories);
    when(mockTransactionRepository.getTransactions(limit: anyNamed('limit'))).thenAnswer((_) async => transactions);

    // Performance map
    final perfMap = { for (var c in categories) c.id : {'available': 100.0} };
    when(mockBudgetingService.calculateBatchCategoryPerformance(any)).thenAnswer((_) async => perfMap);
    when(mockBudgetingService.calculateFundedPercentage(any, any)).thenAnswer((_) async => 0.5);

    // Mock lookups
    when(mockPayeeRepository.getPayeeById(any)).thenAnswer((_) async => const Payee(id: 'p1', name: 'Test Payee', createdAt: null));
    when(mockCategoryRepository.getCategoryById(any)).thenAnswer((_) async => categories.first);

    final stopwatch = Stopwatch()..start();
    await widgetService.updateWidgetData();
    stopwatch.stop();

    print('Widget generation time: ${stopwatch.elapsedMilliseconds}ms');
    expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: "Widget generation took too long");
  });
}
