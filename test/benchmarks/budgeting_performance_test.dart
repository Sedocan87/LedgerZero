// ignore_for_file: avoid_print
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/repositories/transaction_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_repository_impl.dart';
import 'package:ledger_zero/data/repositories/category_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_template_repository_impl.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

// ignore_for_file: prefer_const_constructors

void main() {
  late AppDatabase database;
  late TransactionRepositoryImpl transactionRepository;
  late BudgetRepositoryImpl budgetRepository;
  late CategoryRepositoryImpl categoryRepository;
  late BudgetTemplateRepositoryImpl budgetTemplateRepository;
  late BudgetingService budgetingService;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    transactionRepository = TransactionRepositoryImpl(database.transactionsDao);
    budgetRepository = BudgetRepositoryImpl(database.budgetsDao);
    categoryRepository = CategoryRepositoryImpl(database.categoriesDao);
    budgetTemplateRepository = BudgetTemplateRepositoryImpl(database.budgetTemplatesDao);
    budgetingService = BudgetingService(
      transactionRepository: transactionRepository,
      budgetRepository: budgetRepository,
      categoryRepository: categoryRepository,
      budgetTemplateRepository: budgetTemplateRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> generateData({
    required int transactionCount,
    required int categoryCount,
  }) async {
    // 1. Create Account
    const accountId = 'acc_1';
    await database.into(database.accounts).insert(
      AccountsCompanion(
        id: Value(accountId),
        name: const Value('Test Account'),
        type: const Value('checking'),
        createdAt: Value(DateTime.now()),
      ),
    );

    // 2. Create Categories
    final categoryIds = <String>[];
    for (int i = 0; i < categoryCount; i++) {
      final id = 'cat_$i';
      categoryIds.add(id);
      await database.into(database.categories).insert(
        CategoriesCompanion(
          id: Value(id),
          name: Value('Category $i'),
          createdAt: Value(DateTime.now()),
        ),
      );
    }

    // 3. Create Transactions
    // Spread over the last 12 months
    final now = DateTime.now();
    const batchSize = 1000;

    for (int i = 0; i < transactionCount; i += batchSize) {
      await database.batch((batch) {
        for (int j = i; j < i + batchSize && j < transactionCount; j++) {
          final date = now.subtract(Duration(days: j % 365));
          // Mix of income (null category) and expense
          final isIncome = j % 10 == 0;
          final categoryId = isIncome ? null : categoryIds[j % categoryCount];

          batch.insert(
            database.transactions,
            TransactionsCompanion(
              id: Value('tx_$j'),
              accountId: Value(accountId),
              date: Value(date),
              amount: Value(isIncome ? 1000.0 : -50.0),
              categoryId: Value(categoryId),
              cleared: const Value(0), // uncleared
              approved: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      });
    }

    // 4. Create some budgets
    for (var catId in categoryIds) {
      await database.into(database.budgets).insert(
        BudgetsCompanion(
          id: Value('budget_${catId}_${now.month}'),
          categoryId: Value(catId),
          month: Value('${now.year}-${now.month.toString().padLeft(2, '0')}'),
          budgeted: const Value(100.0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
  }

  test('Budgeting Performance Test with 10,000 transactions', () async {
    const transactionCount = 10000;
    const categoryCount = 50;

    // print('Generating $transactionCount transactions...');
    final stopwatchGen = Stopwatch()..start();
    await generateData(transactionCount: transactionCount, categoryCount: categoryCount);
    stopwatchGen.stop();
    // print('Data generation took: ${stopwatchGen.elapsedMilliseconds}ms');

    final targetMonth = DateTime.now();

    // Measure calculateTBB
    // print('Running calculateTBB...');
    final stopwatchTBB = Stopwatch()..start();
    final tbb = await budgetingService.calculateTBB(targetMonth);
    stopwatchTBB.stop();
    // print('calculateTBB took: ${stopwatchTBB.elapsedMilliseconds}ms');
    // print('TBB Result: $tbb');

    // Measure calculateCategoryAvailable
    const testCategoryId = 'cat_0';
    // print('Running calculateCategoryAvailable for $testCategoryId...');
    final stopwatchCat = Stopwatch()..start();
    final available = await budgetingService.calculateCategoryAvailable(testCategoryId, targetMonth);
    stopwatchCat.stop();
    // print('calculateCategoryAvailable took: ${stopwatchCat.elapsedMilliseconds}ms');
    // print('Available Result: $available');

    // Measure calculateBatchCategoryPerformance
    // print('Running calculateBatchCategoryPerformance...');
    final stopwatchBatch = Stopwatch()..start();
    final batchResult = await budgetingService.calculateBatchCategoryPerformance(targetMonth);
    stopwatchBatch.stop();
    // print('calculateBatchCategoryPerformance took: ${stopwatchBatch.elapsedMilliseconds}ms');
    // print('Batch Result Size: ${batchResult.length}');

    // Expectations
    expect(tbb, isNotNull);
    expect(available, isNotNull);
    expect(batchResult, isNotEmpty);
    expect(stopwatchBatch.elapsedMilliseconds, lessThan(200)); // Should be fast
  });
}
