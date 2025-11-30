import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/budgets.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/category_groups.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';
import 'package:ledger_zero/data/database/tables/scheduled_transactions.dart';
import 'package:ledger_zero/data/database/tables/sync_log.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  Budgets,
  Categories,
  CategoryGroups,
  Transactions,
  Payees,
  ScheduledTransactions,
  SyncLog,
])
class AppDatabase extends _$AppDatabase {
  // The QueryExecutor is passed to the super constructor.
  // This allows us to use different executors for testing (e.g. in-memory)
  // vs production (e.g. file-based).
  AppDatabase(super.e);

  // Default connection for the application
  AppDatabase.defaultConnection() : super(openConnection());

  @override
  int get schemaVersion => 1;
}
