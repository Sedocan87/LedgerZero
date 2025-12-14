import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase database;
  late BudgetsDao budgetsDao;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    budgetsDao = BudgetsDao(database);

    // Seed dependencies (Categories)
    // We need 100 categories
    final categories = List.generate(
      100,
      (i) => CategoriesCompanion.insert(id: 'cat_$i', name: 'Category $i'),
    );
    await database.batch((batch) {
      batch.insertAll(database.categories, categories);
    });
  });

  tearDown(() async {
    await database.close();
  });

  test('Budget aggregation performance', () async {
    // Insert 1000 budget entries across 100 categories and 12 months
    const categories = 100;
    const months = 12;

    final budgets = <BudgetsCompanion>[];
    for (var c = 0; c < categories; c++) {
      for (var m = 0; m < months; m++) {
        budgets.add(
          BudgetsCompanion.insert(
            id: 'b_${c}_$m',
            categoryId: 'cat_$c',
            month: '2023-${m.toString().padLeft(2, '0')}',
            budgeted: const Value(100.0),
            activity: const Value(50.0),
          ),
        );
      }
    }

    // Use batch for insertion
    await database.batch((batch) {
      batch.insertAll(database.budgets, budgets);
    });

    final stopwatch = Stopwatch()..start();

    // Test: Get total budgeted for '2023-12' (cumulative)
    await budgetsDao.getTotalBudgetedByMonthRange('2023-11');

    stopwatch.stop();
    // print('Budget aggregation (sum 1200 rows) took ${stopwatch.elapsedMilliseconds}ms');
  });
}
