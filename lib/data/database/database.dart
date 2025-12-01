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

import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:ledger_zero/data/database/daos/categories_dao.dart';
import 'package:ledger_zero/data/database/daos/payees_dao.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/sync_log_dao.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Budgets,
    Categories,
    CategoryGroups,
    Transactions,
    Payees,
    ScheduledTransactions,
    SyncLog,
  ],
  daos: [
    AccountsDao,
    BudgetsDao,
    CategoriesDao,
    PayeesDao,
    ScheduledTransactionsDao,
    SyncLogDao,
    TransactionsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  // The QueryExecutor is passed to the super constructor.
  // This allows us to use different executors for testing (e.g. in-memory)
  // vs production (e.g. file-based).
  AppDatabase(super.e);

  // Default connection for the application
  AppDatabase.defaultConnection() : super(openConnection());

  static final AppDatabase _instance = AppDatabase.defaultConnection();
  static AppDatabase get instance => _instance;

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add new columns to categories table
          await m.addColumn(categories, categories.goalType);
          await m.addColumn(categories, categories.targetAmount);
          await m.addColumn(categories, categories.targetDate);
        }
        if (from < 3) {
          // Add is_deleted column to transactions table
          await m.addColumn(transactions, transactions.isDeleted);
        }
        if (from < 4) {
          // Add new columns to accounts table
          await m.addColumn(accounts, accounts.color);
          await m.addColumn(accounts, accounts.icon);
          await m.addColumn(accounts, accounts.notes);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
