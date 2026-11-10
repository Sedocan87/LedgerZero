import 'package:drift/drift.dart';
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

/// The database file has a schema older than
/// [AppDatabase.minimumSchemaVersion], which this version does not upgrade.
class UnsupportedSchemaException implements Exception {
  const UnsupportedSchemaException(this.version);

  final int version;

  @override
  String toString() =>
      'UnsupportedSchemaException: schema v$version is older than '
      'v${AppDatabase.minimumSchemaVersion}';
}

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
  static const int currentSchemaVersion = 20;

  /// The oldest schema this version opens or restores (see the
  /// `onUpgrade` step in [migration]).
  static const int minimumSchemaVersion = 20;

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
        await _createPersonalBalanceTriggers();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v20 is the first schema of the released app: older databases
        // (development builds only) are not upgraded. The start-up screen
        // offers the reset; restoring a backup below v20 is refused
        // (`RestoreService`). The next schema change adds its step here,
        // with drift_schemas/drift_schema_v20.json as its baseline.
        if (from < minimumSchemaVersion) {
          throw UnsupportedSchemaException(from);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = NORMAL');
        await createUnversionedIndexes();
      },
    );
  }

  /// Copies every change from the write-ahead log into the database file
  /// and empties the log (`PRAGMA wal_checkpoint(TRUNCATE)`).
  ///
  /// Called when the app goes to the background (`lib/app/app.dart`), the
  /// last moment before Android may stop the process or back the app up
  /// (Auto Backup, device-to-device transfer). The backup copies
  /// `db.sqlite` and `db.sqlite-wal` together while no transaction is
  /// running, which is consistent on its own; after the checkpoint the WAL
  /// is empty, so even a backup taken while the app is in the background
  /// and writing (a sync run) finds the committed data in `db.sqlite`.
  /// Returns false when SQLite could not finish it (a reader or writer was
  /// busy); the next background tries again.
  Future<bool> checkpointWal() async {
    final rows = await customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
    // (busy, log frames, checkpointed frames); busy = 1 means not done.
    return rows.isEmpty || rows.first.data.values.first == 0;
  }

  /// Name of the index on `transactions (parent_transaction_id,
  /// is_deleted)`, see [createUnversionedIndexes].
  static const String splitParentIndex = 'idx_transactions_parent';

  /// Performance indexes that are not part of the versioned drift schema.
  ///
  /// They are created idempotently on every open (`IF NOT EXISTS`), for new
  /// and existing databases alike, so adding one needs no schema version
  /// bump and no migration: an index never changes what is stored or
  /// synced. (Sync does not compare the database schema version: change
  /// files carry `SyncSchema.syncVersion`, which only changes with the
  /// synced tables.)
  ///
  /// * [splitParentIndex]: split children by parent. Used by the split
  ///   parent checks (`TransactionsDao.splitParentCondition`, correlated in
  ///   balance, activity and report queries) and by SQLite's foreign-key
  ///   check when a transaction is deleted.
  Future<void> createUnversionedIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS $splitParentIndex '
      'ON transactions (parent_transaction_id, is_deleted)',
    );
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

  /// `sync_kv` key of this device's household member id: the owner of the
  /// personal accounts created here. It lives in the database (not in
  /// SharedPreferences like the sync device id), so restoring a backup keeps
  /// the accounts personal to the same member.
  static const String memberIdKey = 'member_id';

  /// SQL for this device's member id (NULL until a personal account exists).
  static const String localMemberSql =
      "(SELECT value FROM sync_kv WHERE key = '$memberIdKey')";

  /// SQL for the computed balance of the `accounts` row being updated (see
  /// `AccountsDao.balanceExpression`).
  static const String _ownBalanceSql =
      'starting_balance + COALESCE((SELECT SUM(t.amount) FROM transactions t '
      'WHERE t.account_id = accounts.id AND t.is_deleted = 0 '
      'AND t.parent_transaction_id IS NULL), 0)';

  /// Keeps `accounts.shared_balance` of this member's personal accounts
  /// equal to their computed balance. The transactions of a personal account
  /// never sync, so other members show this column instead; changing it
  /// goes through the accounts sync trigger (new `updated_at`, pending
  /// change), so every balance change reaches them. A shared account has no
  /// shared balance. Like the sync triggers, nothing happens while a change
  /// file is applied.
  Future<void> _createPersonalBalanceTriggers() async {
    String refresh(String where) =>
        'UPDATE accounts SET shared_balance = $_ownBalanceSql '
        'WHERE $where AND owner_id = $localMemberSql '
        'AND shared_balance IS NOT ($_ownBalanceSql);';
    for (final (event, where) in const [
      ('INSERT', 'id = NEW.account_id'),
      ('UPDATE', 'id IN (NEW.account_id, OLD.account_id)'),
      ('DELETE', 'id = OLD.account_id'),
    ]) {
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS
          transactions_${event.toLowerCase()}_personal_balance
        AFTER $event ON transactions
        WHEN $_notApplying
        BEGIN
          ${refresh(where)}
        END;
      ''');
    }
    for (final event in const ['INSERT', 'UPDATE']) {
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS
          accounts_${event.toLowerCase()}_personal_balance
        AFTER $event ON accounts
        WHEN $_notApplying
        BEGIN
          ${refresh('id = NEW.id')}
          UPDATE accounts SET shared_balance = NULL
            WHERE id = NEW.id AND owner_id IS NULL
            AND shared_balance IS NOT NULL;
        END;
      ''');
    }
  }

  /// Brings `shared_balance` of this member's personal accounts back in
  /// line with their transactions. The triggers above are off while a
  /// change file is applied, so an account row replaced by sync (after a
  /// restore, this phone's own newer row from the folder) carries the
  /// balance of the moment it was written, not of the transactions that
  /// are here now. A corrected row is a local edit (new `updated_at`,
  /// captured), so the partner gets it. Returns the number of corrected
  /// accounts.
  Future<int> refreshPersonalBalances() => customUpdate(
    'UPDATE accounts SET shared_balance = $_ownBalanceSql '
    'WHERE owner_id = $localMemberSql '
    'AND shared_balance IS NOT ($_ownBalanceSql)',
    updates: {accounts},
    updateKind: UpdateKind.update,
  );

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
