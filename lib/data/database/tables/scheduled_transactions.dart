import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';

class ScheduledTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get payeeId => text().nullable().references(Payees, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Amount in minor units (negative = outflow).
  IntColumn get amount => integer().nullable()();
  TextColumn get frequency =>
      text().nullable()(); // daily, weekly, monthly, yearly
  IntColumn get interval => integer().nullable()(); // Every N days/weeks/etc
  IntColumn get occurrenceCount =>
      integer().nullable()(); // Stop after N occurrences
  DateTimeColumn get nextDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get autoApprove => boolean().withDefault(const Constant(false))();

  /// Memo copied to each generated transaction (schema v16).
  TextColumn get memo => text().nullable()();

  /// Day of month (1-31) monthly/yearly schedules aim for (schema v16).
  /// Keeps "every month on the 31st" on the 31st after a short month clamps
  /// one occurrence to the 28th/30th. `null` means: the day of `next_date`.
  IntColumn get anchorDay => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
