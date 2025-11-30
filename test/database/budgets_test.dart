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
    const categoryId = 'cat_1';
    await database.into(database.categories).insert(
      const CategoriesCompanion(
        id: Value(categoryId),
        name: Value('Groceries'),
      ),
    );

    const budget = BudgetsCompanion(
      id: Value('budget_1'),
      categoryId: Value(categoryId),
      month: Value('2023-10'),
      budgeted: Value(100.0),
    );

    await database.into(database.budgets).insert(budget);

    final result = await database.select(database.budgets).get();
    expect(result.length, 1);
    expect(result.first.budgeted, 100.0);
  });

  test('should enforce unique constraint on categoryId and month', () async {
    const categoryId = 'cat_1';
    await database.into(database.categories).insert(
      const CategoriesCompanion(
        id: Value(categoryId),
        name: Value('Groceries'),
      ),
    );

    await database.into(database.budgets).insert(
      const BudgetsCompanion(
        id: Value('budget_1'),
        categoryId: Value(categoryId),
        month: Value('2023-10'),
      ),
    );

    // Try inserting another budget for same category and month
    expect(
      () => database.into(database.budgets).insert(
        const BudgetsCompanion(
          id: Value('budget_2'),
          categoryId: Value(categoryId),
          month: Value('2023-10'),
        ),
      ),
      throwsA(isA<SqliteException>()),
    );
  });
}
