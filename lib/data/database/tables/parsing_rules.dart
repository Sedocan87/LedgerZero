import 'package:drift/drift.dart';

class ParsingRules extends Table {
  TextColumn get id => text()();
  TextColumn get keyword => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get payeeId => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
