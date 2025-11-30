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

  test('payees table should allow inserting data', () async {
    final payee = PayeesCompanion(
      id: const Value('payee_1'),
      name: const Value('Walmart'),
      createdAt: Value(DateTime.now()),
    );

    await database.into(database.payees).insert(payee);

    final result = await database.select(database.payees).get();

    expect(result.length, 1);
    expect(result.first.id, 'payee_1');
    expect(result.first.name, 'Walmart');
    expect(result.first.autoCategoryId, null);
  });

  test('payees table should allow referencing a category', () async {
    // Create a category first
    const category = CategoriesCompanion(
      id: Value('cat_1'),
      name: Value('Groceries'),
    );
    await database.into(database.categories).insert(category);

    final payee = PayeesCompanion(
      id: const Value('payee_2'),
      name: const Value('Costco'),
      autoCategoryId: const Value('cat_1'),
      createdAt: Value(DateTime.now()),
    );

    await database.into(database.payees).insert(payee);

    final result = await database.select(database.payees).get();

    expect(result.length, 1);
    expect(result.first.id, 'payee_2');
    expect(result.first.autoCategoryId, 'cat_1');
  });
}
