import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';

class Payees extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get autoCategoryId => text().nullable().references(Categories, #id)();
  TextColumn get defaultAccountId => text().nullable().references(Accounts, #id)();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
