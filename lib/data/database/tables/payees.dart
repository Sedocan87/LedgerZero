import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';

@TableIndex(name: 'idx_payees_name', columns: {#name})
@TableIndex(name: 'idx_payees_is_favorite', columns: {#isFavorite})
class Payees extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get autoCategoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get defaultAccountId =>
      text().nullable().references(Accounts, #id)();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  TextColumn get icon => text().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
