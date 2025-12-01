import 'package:drift/drift.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // checking, savings, credit, cash
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  RealColumn get startingBalance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
