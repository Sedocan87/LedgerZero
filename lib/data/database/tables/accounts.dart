import 'package:drift/drift.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // checking, savings, credit, cash
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  /// Opening balance in minor units (hundredths). The current balance is
  /// never stored: it is computed as starting balance + SUM(amount) of the
  /// account's non-deleted transactions that are not split children.
  IntColumn get startingBalance => integer().withDefault(const Constant(0))();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();

  /// Whether the account belongs to the budget (schema v19). An off-budget
  /// (tracking) account counts towards net worth only: its starting
  /// balance and transactions never reach To Be Budgeted or categories.
  BoolColumn get onBudget => boolean().withDefault(const Constant(true))();

  /// Household member who owns a personal account (schema v20); null for a
  /// shared account. A personal account is always off-budget, and its
  /// transactions and scheduled transactions never leave the owner's
  /// device: other members only get this row (see docs/SYNC_ARCHITECTURE.md,
  /// "Personal accounts").
  TextColumn get ownerId => text().nullable()();

  /// The balance of a personal account as last computed on the owner's
  /// device (kept by triggers there), so other members can show it. Null
  /// for shared accounts.
  IntColumn get sharedBalance => integer().nullable()();
  IntColumn get color => integer().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
