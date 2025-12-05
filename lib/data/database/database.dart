import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/budget_templates.dart';
import 'package:ledger_zero/data/database/tables/budgets.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/category_groups.dart';
import 'package:ledger_zero/data/database/tables/import_profiles.dart';
import 'package:ledger_zero/data/database/tables/parsing_history.dart';
import 'package:ledger_zero/data/database/tables/parsing_rules.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';
import 'package:ledger_zero/data/database/tables/pending_sync_changes.dart';
import 'package:ledger_zero/data/database/tables/report_notes.dart';
import 'package:ledger_zero/data/database/tables/rules.dart';
import 'package:ledger_zero/data/database/tables/scheduled_transactions.dart';
import 'package:ledger_zero/data/database/tables/sync_log.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';

import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:ledger_zero/data/database/daos/budget_templates_dao.dart';
import 'package:ledger_zero/data/database/daos/categories_dao.dart';
import 'package:ledger_zero/data/database/daos/import_profiles_dao.dart';
import 'package:ledger_zero/data/database/daos/parsing_history_dao.dart';
import 'package:ledger_zero/data/database/daos/parsing_rules_dao.dart';
import 'package:ledger_zero/data/database/daos/payees_dao.dart';
import 'package:ledger_zero/data/database/daos/report_notes_dao.dart';
import 'package:ledger_zero/data/database/daos/rules_dao.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/sync_log_dao.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/pending_sync_changes_dao.dart';
import 'package:uuid/uuid.dart';

// Explicit imports for types used in generated code
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Budgets,
    BudgetTemplates,
    Categories,
    CategoryGroups,
    Transactions,
    Payees,
    ReportNotes,
    ScheduledTransactions,
    SyncLog,
    PendingSyncChanges,
    ParsingHistory,
    ParsingRules,
    ImportProfiles,
    Rules,
  ],
  daos: [
    AccountsDao,
    BudgetsDao,
    BudgetTemplatesDao,
    CategoriesDao,
    PayeesDao,
    ReportNotesDao,
    ScheduledTransactionsDao,
    SyncLogDao,
    TransactionsDao,
    PendingSyncChangesDao,
    ParsingHistoryDao,
    ParsingRulesDao,
    ImportProfilesDao,
    RulesDao,
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
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedDefaultCategories();
        await _createSyncTriggers();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 14) {
          await m.createTable(rules);
          await _createSyncTriggersForTable('rules');
        }
        if (from < 13) {
           await m.createTable(importProfiles);
        }
        if (from < 12) {
          await m.createTable(parsingHistory);
          await m.createTable(parsingRules);
        }
        if (from < 11) {
          await m.createTable(pendingSyncChanges);
          await _createSyncTriggers();
        }
        if (from < 10) {
          // Add interval and occurrenceCount to scheduled_transactions
          await m.addColumn(scheduledTransactions, scheduledTransactions.interval);
          await m.addColumn(scheduledTransactions, scheduledTransactions.occurrenceCount);
        }
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
        if (from < 5) {
          // Add new columns to categories table
          await m.addColumn(categories, categories.color);
          await m.addColumn(categories, categories.icon);
        }
        if (from < 6) {
          // Add budget templates table
          await m.createTable(budgetTemplates);
        }
        if (from < 7) {
          // Add report notes table
          await m.createTable(reportNotes);
        }
        if (from < 8) {
          // Add new columns to payees table
          await m.addColumn(payees, payees.icon);
          await m.addColumn(payees, payees.color);
          await m.addColumn(payees, payees.notes);
          await m.addColumn(payees, payees.isFavorite);
        }
        if (from < 9) {
          // Add indices for payee optimization
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_payee ON transactions (payee_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_payees_name ON payees (name)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_payees_is_favorite ON payees (is_favorite)');
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createSyncTriggersForTable(String table) async {
      // INSERT
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_insert_trigger
        AFTER INSERT ON $table
        BEGIN
          INSERT INTO pending_sync_changes (table_name, record_id, action)
          VALUES ('$table', NEW.id, 'INSERT');
        END;
      ''');

      // UPDATE
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_update_trigger
        AFTER UPDATE ON $table
        BEGIN
          INSERT INTO pending_sync_changes (table_name, record_id, action)
          VALUES ('$table', NEW.id, 'UPDATE');
        END;
      ''');

      // DELETE
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_delete_trigger
        AFTER DELETE ON $table
        BEGIN
          INSERT INTO pending_sync_changes (table_name, record_id, action)
          VALUES ('$table', OLD.id, 'DELETE');
        END;
      ''');
  }

  Future<void> _createSyncTriggers() async {
    final tables = [
      'accounts',
      'categories',
      'category_groups',
      'transactions',
      'payees',
      'budgets',
      'scheduled_transactions',
      'budget_templates',
      'report_notes',
      'import_profiles',
      'rules',
    ];

    for (final table in tables) {
      await _createSyncTriggersForTable(table);
    }
  }

  /// Checks if the database is currently using encryption (SQLCipher).
  Future<bool> get isEncrypted async {
    try {
      final result = await customSelect(
        'PRAGMA cipher_version',
        readsFrom: {},
      ).get();
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _seedDefaultCategories() async {
    const uuid = Uuid();
    final now = DateTime.now();

    // Define defaults
    final defaults = {
      'Immediate Obligations': [
        'Rent/Mortgage',
        'Electric',
        'Water',
        'Internet',
        'Groceries',
        'Transportation'
      ],
      'True Expenses': [
        'Medical',
        'Auto Maintenance',
        'Home Maintenance',
        'Renter\'s/Home Insurance',
        'Software Subscriptions'
      ],
      'Debt Payments': ['Student Loan', 'Car Payment', 'Credit Card'],
      'Quality of Life': [
        'Vacation',
        'Fitness',
        'Education',
        'Dining Out',
        'Entertainment'
      ],
      'Just for Fun': ['Gaming', 'Music', 'Fun Money'],
    };

    int groupSort = 0;

    await batch((batch) {
      for (final entry in defaults.entries) {
        final groupId = uuid.v4();
        batch.insert(
            categoryGroups,
            CategoryGroupsCompanion.insert(
              id: groupId,
              name: entry.key,
              sortOrder: Value(groupSort++),
              createdAt: Value(now),
            ));

        int catSort = 0;
        for (final catName in entry.value) {
          batch.insert(
              categories,
              CategoriesCompanion.insert(
                id: uuid.v4(),
                name: catName,
                categoryGroupId: Value(groupId),
                sortOrder: Value(catSort++),
                createdAt: Value(now),
              ));
        }
      }
    });
  }
}
