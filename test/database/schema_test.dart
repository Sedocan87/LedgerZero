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

  test('category_groups table should allow inserting data', () async {
    final categoryGroup = CategoryGroupsCompanion(
      id: Value('group_1'),
      name: Value('Living Expenses'),
      sortOrder: Value(1),
      createdAt: Value(DateTime.now()),
    );

    await database.into(database.categoryGroups).insert(categoryGroup);

    final result = await database.select(database.categoryGroups).get();

    expect(result.length, 1);
    expect(result.first.id, 'group_1');
    expect(result.first.name, 'Living Expenses');
  });
}
