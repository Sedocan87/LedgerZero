import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('should insert budget successfully', () async {
    // Need a category first
    final categoryId = 'cat_1';
    await database.into(database.categories).insert(
      CategoriesCompanion(
        id: Value(categoryId),
        name: const Value('Groceries'),
      ),
    );

    final budget = BudgetsCompanion(
      id: const Value('budget_1'),
      categoryId: Value(categoryId),
      month: const Value('2023-10'),
      budgeted: const Value(100.0),
    );

    await database.into(database.budgets).insert(budget);

    final result = await database.select(database.budgets).get();
    expect(result.length, 1);
    expect(result.first.budgeted, 100.0);
  });

  test('should enforce unique constraint on categoryId and month', () async {
    final categoryId = 'cat_1';
    await database.into(database.categories).insert(
      CategoriesCompanion(
        id: Value(categoryId),
        name: const Value('Groceries'),
      ),
    );

    await database.into(database.budgets).insert(
      BudgetsCompanion(
        id: const Value('budget_1'),
        categoryId: Value(categoryId),
        month: const Value('2023-10'),
      ),
    );

    // Try inserting another budget for same category and month
    expect(
      () => database.into(database.budgets).insert(
        BudgetsCompanion(
          id: const Value('budget_2'),
          categoryId: Value(categoryId),
          month: const Value('2023-10'),
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
