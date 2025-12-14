// ignore_for_file: avoid_print
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/repositories/budget_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_template_repository_impl.dart';
import 'package:ledger_zero/data/repositories/category_repository_impl.dart';
import 'package:ledger_zero/data/repositories/transaction_repository_impl.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

void main() {
  late AppDatabase database;
  late BudgetingService budgetingService;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    final transactionRepository = TransactionRepositoryImpl(
      database.transactionsDao,
    );
    final budgetRepository = BudgetRepositoryImpl(database.budgetsDao);
    final categoryRepository = CategoryRepositoryImpl(database.categoriesDao);
    final budgetTemplateRepository = BudgetTemplateRepositoryImpl(
      database.budgetTemplatesDao,
    );

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

  test('Concurrent budget edits should result in consistent state', () async {
    // Setup category
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion(
            id: const Value('cat_1'),
            name: const Value('Test Category'),
            createdAt: Value(DateTime.now()),
          ),
        );

    final month = DateTime(2025, 1);

    // Simulate two concurrent operations trying to set the budget
    // Both start at the same time.
    final future1 = budgetingService.setCategoryBudgetedAmount(
      'cat_1',
      100.0,
      month,
    );
    final future2 = budgetingService.setCategoryBudgetedAmount(
      'cat_1',
      200.0,
      month,
    );

    // Both should succeed now that we handle the race condition
    await Future.wait([future1, future2]);

    // Check final state
    final budgets = await database.budgetsDao.getBudgetsForMonth('2025-01');
    expect(budgets.length, 1);

    print('Final budgeted amount: ${budgets.first.budgeted}');
  });
}
