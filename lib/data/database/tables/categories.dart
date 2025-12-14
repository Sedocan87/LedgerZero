import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/category_groups.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryGroupId =>
      text().nullable().references(CategoryGroups, #id)();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().nullable()();
  TextColumn get goalType => text().nullable()();
  RealColumn get targetAmount => real().nullable()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
