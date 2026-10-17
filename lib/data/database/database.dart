import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/budget_templates.dart';
import 'package:ledger_zero/data/database/tables/budgets.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/category_groups.dart';
import 'package:ledger_zero/data/database/tables/import_profiles.dart';
import 'package:ledger_zero/data/database/tables/parsing_history.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';
import 'package:ledger_zero/data/database/tables/pending_sync_changes.dart';
import 'package:ledger_zero/data/database/tables/report_notes.dart';
import 'package:ledger_zero/data/database/tables/rules.dart';
import 'package:ledger_zero/data/database/tables/scheduled_transactions.dart';
import 'package:ledger_zero/data/database/tables/sync_tables.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';

import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:ledger_zero/data/database/daos/budget_templates_dao.dart';
import 'package:ledger_zero/data/database/daos/categories_dao.dart';
import 'package:ledger_zero/data/database/daos/import_profiles_dao.dart';
import 'package:ledger_zero/data/database/daos/parsing_history_dao.dart';
import 'package:ledger_zero/data/database/daos/payees_dao.dart';
import 'package:ledger_zero/data/database/daos/report_notes_dao.dart';
import 'package:ledger_zero/data/database/daos/rules_dao.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/sync_dao.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/pending_sync_changes_dao.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';

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
    PendingSyncChanges,
    ParsingHistory,
    ImportProfiles,
    Rules,
    SyncDeviceProgress,
    SyncKv,
    SyncRowVersions,
    SyncConflicts,
    SyncQuarantine,
    SyncApplying,
  ],
  daos: [
    AccountsDao,
    BudgetsDao,
    BudgetTemplatesDao,
    CategoriesDao,
    PayeesDao,
    ReportNotesDao,
    ScheduledTransactionsDao,
    SyncDao,
    TransactionsDao,
    PendingSyncChangesDao,
    ParsingHistoryDao,
    ImportProfilesDao,
    RulesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  // The QueryExecutor is passed to the super constructor.
  // This allows us to use different executors for testing (e.g. in-memory)
  // vs production (e.g. file-based).
  ///
  /// [seedName] maps the English name of a default group/category to the
  /// name it gets in a new database (the app language); ids are always
  /// derived from the English name.
  AppDatabase(super.e, {String Function(String englishName)? seedName})
    : _seedName = seedName ?? _englishName;

  final String Function(String englishName) _seedName;

  static String _englishName(String name) => name;

  /// The current schema version (also used to validate restored backups).
  static const int currentSchemaVersion = 19;

  @override
  int get schemaVersion => currentSchemaVersion;

  /// Tables whose changes are tracked in `pending_sync_changes` by triggers.
  static const List<String> syncedTables = [
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

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedDefaultCategories();
        await _createSyncTriggers();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Steps run in ascending order. Steps that create tables use the
        // current table definitions, so later steps (notably v15) must be
        // idempotent with respect to columns that already exist.
        if (from < 2) {
          await m.addColumn(categories, categories.goalType);
          await m.addColumn(categories, categories.targetAmount);
          await m.addColumn(categories, categories.targetDate);
        }
        if (from < 3) {
          await m.addColumn(transactions, transactions.isDeleted);
        }
        if (from < 4) {
          await m.addColumn(accounts, accounts.color);
          await m.addColumn(accounts, accounts.icon);
          await m.addColumn(accounts, accounts.notes);
        }
        if (from < 5) {
          await m.addColumn(categories, categories.color);
          await m.addColumn(categories, categories.icon);
        }
        if (from < 6) {
          await m.createTable(budgetTemplates);
        }
        if (from < 7) {
          await m.createTable(reportNotes);
        }
        if (from < 8) {
          await m.addColumn(payees, payees.icon);
          await m.addColumn(payees, payees.color);
          await m.addColumn(payees, payees.notes);
          await m.addColumn(payees, payees.isFavorite);
        }
        if (from < 9) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_transactions_payee ON transactions (payee_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_payees_name ON payees (name)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_payees_is_favorite ON payees (is_favorite)',
          );
        }
        if (from < 10) {
          await m.addColumn(
            scheduledTransactions,
            scheduledTransactions.interval,
          );
          await m.addColumn(
            scheduledTransactions,
            scheduledTransactions.occurrenceCount,
          );
        }
        if (from < 11) {
          // Sync triggers for every table are (re)created by the v17 step.
          await m.createTable(pendingSyncChanges);
        }
        if (from < 12) {
          // v12 also created `parsing_rules`; v18 drops it again, so it is
          // not created any more.
          await m.createTable(parsingHistory);
        }
        if (from < 13) {
          await m.createTable(importProfiles);
        }
        if (from < 14) {
          await m.createTable(rules);
        }
        if (from < 15) {
          await _migrateToV15(m);
        }
        if (from < 16) {
          // v16: memo and anchor day of scheduled transactions. The v15
          // step rebuilds scheduled_transactions from the current
          // definition, so the columns may already exist.
          await _addMissingColumns(m, scheduledTransactions);
        }
        if (from < 17) {
          await _migrateToV17(m);
        }
        if (from < 18) {
          // v18: quick-add keyword rules were never created by the app (no
          // UI); the table is dropped. It was never synced.
          await customStatement('DROP TABLE IF EXISTS parsing_rules');
        }
        if (from < 19) {
          // v19: off-budget (tracking) accounts. Existing accounts stay in
          // the budget. The v15 step rebuilds accounts from the current
          // definition, so the column may already exist.
          await _addMissingColumns(m, accounts);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = NORMAL');
      },
    );
  }

  /// Schema v15: money as integer minor units, computed balances and
  /// activity, `updated_at` everywhere, UTC date storage.
  ///
  /// * REAL amounts become INTEGER hundredths via
  ///   `CAST(ROUND(x * 100) AS INTEGER)` (tables are rebuilt with
  ///   [Migrator.alterTable]).
  /// * `accounts.current_balance`, `budgets.activity` and
  ///   `budgets.available` are dropped (they are always computed).
  /// * `updated_at` is added to categories, category_groups, payees,
  ///   scheduled_transactions, budget_templates and import_profiles.
  /// * Columns missing on very old schemas (v1 lacked
  ///   `transactions.parent_transaction_id` and `payees.default_account_id`)
  ///   are added.
  /// * Budget template JSON and rule amount conditions are rewritten to
  ///   minor units.
  /// * Stored DateTimes are rewritten as UTC ISO-8601 (`...Z`); date-only
  ///   columns become UTC midnight of the calendar day they showed locally.
  /// * Sync triggers are dropped before and recreated after the rewrite
  ///   (rebuilding a table drops its triggers anyway), so the migration
  ///   itself does not enqueue sync changes.
  Future<void> _migrateToV15(Migrator m) async {
    for (final table in syncedTables) {
      await _dropSyncTriggersForTable(table);
    }

    await _rebuildTable(m, accounts, moneyColumns: const ['starting_balance']);
    await _rebuildTable(m, budgets, moneyColumns: const ['budgeted']);
    await _rebuildTable(m, categories, moneyColumns: const ['target_amount']);
    await _rebuildTable(
      m,
      scheduledTransactions,
      moneyColumns: const ['amount'],
    );
    await _rebuildTable(m, transactions, moneyColumns: const ['amount']);

    for (final table in <TableInfo>[
      categoryGroups,
      payees,
      budgetTemplates,
      importProfiles,
    ]) {
      await _addMissingColumns(m, table);
    }

    await _convertBudgetTemplateDataToMinorUnits();
    await _convertRuleAmountConditions();
    await _convertDateTimesToUtc();
    // The sync triggers are recreated by the v17 step (they reference the
    // v17 table `sync_applying`).
  }

  /// Schema v17: sync format v2 (see docs/SYNC_ARCHITECTURE.md).
  ///
  /// * New local bookkeeping tables (`sync_device_progress`, `sync_kv`,
  ///   `sync_row_versions`, `sync_conflicts`, `sync_quarantine`,
  ///   `sync_applying`); `sync_log` (filename log of format v1) is dropped.
  /// * `pending_sync_changes.old_updated_at` and an index on
  ///   (table_name, record_id).
  /// * The sync triggers are recreated: they skip writes made while a change
  ///   file is applied, record millisecond change times and fill in
  ///   `updated_at` when a write left it unchanged.
  /// * Pending changes of format v1 are discarded: enabling sync uploads
  ///   every row anyway.
  Future<void> _migrateToV17(Migrator m) async {
    for (final table in syncedTables) {
      await _dropSyncTriggersForTable(table);
    }
    await _addMissingColumns(m, pendingSyncChanges);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_pending_sync_record '
      'ON pending_sync_changes (table_name, record_id)',
    );
    for (final table in <TableInfo>[
      syncDeviceProgress,
      syncKv,
      syncRowVersions,
      syncConflicts,
      syncQuarantine,
      syncApplying,
    ]) {
      await m.createTable(table);
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_row_versions_deleted '
      'ON sync_row_versions (deleted, version)',
    );
    await customStatement('DROP TABLE IF EXISTS sync_log');
    await customStatement('DELETE FROM pending_sync_changes');
    await _createSyncTriggers();
  }

  Future<Set<String>> _existingColumns(String table) async {
    final rows = await customSelect('PRAGMA table_info("$table")').get();
    return {for (final row in rows) row.read<String>('name')};
  }

  /// Rebuilds [table] from its current definition, converting
  /// [moneyColumns] from REAL major units to INTEGER minor units and leaving
  /// columns that did not exist before at their default.
  Future<void> _rebuildTable(
    Migrator m,
    TableInfo table, {
    List<String> moneyColumns = const [],
  }) async {
    final existing = await _existingColumns(table.actualTableName);
    final transformers = <GeneratedColumn, Expression>{};
    final newColumns = <GeneratedColumn>[];
    for (final column in table.$columns) {
      if (!existing.contains(column.name)) {
        newColumns.add(column);
      } else if (moneyColumns.contains(column.name)) {
        transformers[column] = CustomExpression<int>(
          'CAST(ROUND("${column.name}" * 100) AS INTEGER)',
        );
      }
    }
    await m.alterTable(
      TableMigration(
        table,
        columnTransformer: transformers,
        newColumns: newColumns,
      ),
    );
  }

  Future<void> _addMissingColumns(Migrator m, TableInfo table) async {
    final existing = await _existingColumns(table.actualTableName);
    for (final column in table.$columns) {
      if (!existing.contains(column.name)) {
        await m.addColumn(table, column);
      }
    }
  }

  Future<void> _convertBudgetTemplateDataToMinorUnits() async {
    final rows = await customSelect(
      'SELECT id, data FROM budget_templates',
    ).get();
    for (final row in rows) {
      final id = row.read<String>('id');
      final raw = row.read<String>('data');
      final converted = <String, int>{};
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is num) {
            converted[key] = Money.fromMajor(value);
          }
        });
      } catch (_) {
        // Unreadable template data is replaced by an empty template.
      }
      await customUpdate(
        'UPDATE budget_templates SET data = ? WHERE id = ?',
        variables: [
          Variable.withString(jsonEncode(converted)),
          Variable.withString(id),
        ],
        updates: {budgetTemplates},
      );
    }
  }

  Future<void> _convertRuleAmountConditions() async {
    final rows = await customSelect('SELECT id, conditions FROM rules').get();
    const converter = RuleConditionListConverter();
    for (final row in rows) {
      final id = row.read<String>('id');
      final raw = row.read<String>('conditions');
      try {
        // fromSql understands the legacy major-unit amount format;
        // toSql writes minor units.
        final conditions = converter.fromSql(raw);
        await customUpdate(
          'UPDATE rules SET conditions = ? WHERE id = ?',
          variables: [
            Variable.withString(converter.toSql(conditions)),
            Variable.withString(id),
          ],
          updates: {rules},
        );
      } catch (_) {
        // Leave unparsable rows untouched.
      }
    }
  }

  /// Rewrites stored DateTimes as UTC ISO-8601 strings.
  ///
  /// Before v15 drift stored local DateTimes as `2024-05-03T10:00:00.000
  /// +02:00` and UTC ones as `...Z`. Timestamps are converted to the same
  /// instant in UTC. Date-only columns become UTC midnight of the calendar
  /// day the value showed on the device (`substr(…, 1, 10)` for local values,
  /// `date(…, 'localtime')` for UTC values that are not already midnight).
  Future<void> _convertDateTimesToUtc() async {
    const calendarDays = {
      'transactions': ['date'],
      'scheduled_transactions': ['next_date', 'end_date'],
      'categories': ['target_date'],
    };
    const timestamps = {
      'accounts': ['created_at', 'updated_at'],
      'budgets': ['created_at', 'updated_at'],
      'categories': ['created_at', 'updated_at'],
      'category_groups': ['created_at', 'updated_at'],
      'transactions': ['created_at', 'updated_at'],
      'payees': ['created_at', 'updated_at'],
      'scheduled_transactions': ['created_at', 'updated_at'],
      'budget_templates': ['updated_at'],
      'import_profiles': ['updated_at'],
    };
    // TEXT columns written with DateTime.toIso8601String() of a local time
    // (no offset). They are interpreted in the device's current time zone.
    const localTextTimestamps = {
      'budget_templates': ['created_at'],
      'import_profiles': ['created_at'],
      'report_notes': ['created_at', 'updated_at'],
      'rules': ['created_at', 'updated_at'],
      'parsing_history': ['created_at'],
    };

    for (final entry in calendarDays.entries) {
      for (final column in entry.value) {
        final c = '"$column"';
        await customStatement(
          'UPDATE ${entry.key} SET $c = CASE '
          "WHEN $c LIKE '%T00:00:00.000Z' THEN $c "
          "WHEN $c LIKE '%Z' THEN date($c, 'localtime') || 'T00:00:00.000Z' "
          "ELSE substr($c, 1, 10) || 'T00:00:00.000Z' END "
          'WHERE $c IS NOT NULL',
        );
      }
    }

    for (final entry in timestamps.entries) {
      for (final column in entry.value) {
        final c = '"$column"';
        await customStatement(
          "UPDATE ${entry.key} SET $c = strftime('%Y-%m-%dT%H:%M:%fZ', $c) "
          "WHERE $c IS NOT NULL AND $c NOT LIKE '%Z' "
          "AND strftime('%Y-%m-%dT%H:%M:%fZ', $c) IS NOT NULL",
        );
      }
    }

    for (final entry in localTextTimestamps.entries) {
      for (final column in entry.value) {
        final c = '"$column"';
        await customStatement(
          'UPDATE ${entry.key} SET $c = CASE '
          "WHEN $c LIKE '% +__:__' OR $c LIKE '% -__:__' "
          "THEN strftime('%Y-%m-%dT%H:%M:%fZ', $c) "
          "ELSE strftime('%Y-%m-%dT%H:%M:%fZ', $c, 'utc') END "
          "WHERE $c IS NOT NULL AND $c NOT LIKE '%Z' "
          "AND strftime('%Y-%m-%dT%H:%M:%fZ', $c) IS NOT NULL",
        );
      }
    }
  }

  Future<void> _dropSyncTriggersForTable(String table) async {
    for (final suffix in const ['insert', 'update', 'delete']) {
      await customStatement(
        'DROP TRIGGER IF EXISTS ${table}_${suffix}_trigger',
      );
    }
  }

  /// UTC timestamp with millisecond precision, as drift stores DateTimes.
  static const String _sqlNow = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";

  /// Triggers do nothing while a sync change file is applied.
  static const String _notApplying = 'NOT EXISTS (SELECT 1 FROM sync_applying)';

  /// Change capture for [table]: every local insert, update and delete is
  /// recorded in `pending_sync_changes`. Writes that leave `updated_at`
  /// unset (insert) or unchanged (update) get the current time, because
  /// `updated_at` is the conflict timestamp of sync (decision D6).
  Future<void> _createSyncTriggersForTable(String table) async {
    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_insert_trigger
        AFTER INSERT ON $table
        WHEN $_notApplying
        BEGIN
          UPDATE $table SET updated_at = $_sqlNow
            WHERE id = NEW.id AND NEW.updated_at IS NULL;
          INSERT INTO pending_sync_changes
            (table_name, record_id, action, changed_at)
          VALUES ('$table', NEW.id, 'INSERT', $_sqlNow);
        END;
      ''');

    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_update_trigger
        AFTER UPDATE ON $table
        WHEN $_notApplying
        BEGIN
          UPDATE $table SET updated_at = $_sqlNow
            WHERE id = NEW.id AND NEW.updated_at IS OLD.updated_at;
          INSERT INTO pending_sync_changes
            (table_name, record_id, action, changed_at)
          VALUES ('$table', NEW.id, 'UPDATE', $_sqlNow);
        END;
      ''');

    await customStatement('''
        CREATE TRIGGER IF NOT EXISTS ${table}_delete_trigger
        AFTER DELETE ON $table
        WHEN $_notApplying
        BEGIN
          INSERT INTO pending_sync_changes
            (table_name, record_id, action, changed_at, old_updated_at)
          VALUES ('$table', OLD.id, 'DELETE', $_sqlNow, OLD.updated_at);
        END;
      ''');
  }

  Future<void> _createSyncTriggers() async {
    for (final table in syncedTables) {
      await _createSyncTriggersForTable(table);
    }
  }

  /// Whether this connection runs on SQLCipher. True means the library can
  /// encrypt; whether the file actually is encrypted is checked by
  /// `databaseEncryptionStatusProvider` (file header + key).
  Future<bool> get hasCipherSupport async {
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

  /// Creation and update time of the seeded defaults. Fixed, so the seeded
  /// rows are identical on every device and converge without conflicts.
  static final DateTime seedTimestamp = DateTime.utc(2024);

  /// Seeds the default category groups and categories with deterministic
  /// ids (decision D7), so every device seeds identical rows.
  Future<void> _seedDefaultCategories() async {
    final now = seedTimestamp;

    const defaults = DefaultCategories.groups;

    int groupSort = 0;

    await batch((batch) {
      for (final entry in defaults.entries) {
        final groupId = DeterministicId.defaultGroup(entry.key);
        batch.insert(
          categoryGroups,
          CategoryGroupsCompanion.insert(
            id: groupId,
            name: _seedName(entry.key),
            sortOrder: Value(groupSort++),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        int catSort = 0;
        for (final catName in entry.value) {
          batch.insert(
            categories,
            CategoriesCompanion.insert(
              id: DeterministicId.defaultCategory(entry.key, catName),
              name: _seedName(catName),
              categoryGroupId: Value(groupId),
              sortOrder: Value(catSort++),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      }
    });
  }
}
