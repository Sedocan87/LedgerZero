import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';

class ScheduledTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get payeeId => text().nullable().references(Payees, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  RealColumn get amount => real().nullable()();
  TextColumn get frequency => text().nullable()(); // daily, weekly, monthly, yearly
  IntColumn get interval => integer().nullable()(); // Every N days/weeks/etc
  IntColumn get occurrenceCount => integer().nullable()(); // Stop after N occurrences
  DateTimeColumn get nextDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get autoApprove => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
