import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';

@TableIndex(name: 'idx_transactions_account', columns: {#accountId})
@TableIndex(name: 'idx_transactions_date', columns: {#date})
@TableIndex(name: 'idx_transactions_category', columns: {#categoryId})
class Transactions extends Table {
  TextColumn get id => text()();

  @ReferenceName('accountTransactions')
  TextColumn get accountId => text().references(Accounts, #id)();

  DateTimeColumn get date => dateTime()();
  RealColumn get amount => real()();
  TextColumn get payeeId => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get memo => text().nullable()();
  IntColumn get cleared => integer().withDefault(const Constant(0))();
  BoolColumn get approved => boolean().withDefault(const Constant(true))();

  @ReferenceName('transferTransactions')
  TextColumn get transferAccountId => text().nullable().references(Accounts, #id)();

  TextColumn get transferTransactionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
