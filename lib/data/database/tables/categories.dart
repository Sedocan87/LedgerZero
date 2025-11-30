import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryGroupId => text().nullable()();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
