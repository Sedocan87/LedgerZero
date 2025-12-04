import 'package:drift/drift.dart';

class ParsingHistory extends Table {
  TextColumn get id => text()();
  TextColumn get input => text()();
  TextColumn get payeeId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
