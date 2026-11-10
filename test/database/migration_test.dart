// Schema tests (drift schema verifier).
//
// v20 is the first schema of the released app and the baseline: databases
// and backups below it are not upgraded (see `AppDatabase.migration`). The
// next schema change dumps its schema next to drift_schema_v20.json (`dart
// run drift_dev schema dump lib/data/database/database.dart drift_schemas/`),
// regenerates the helpers in generated_migrations/ (`dart run drift_dev
// schema generate drift_schemas/ test/database/generated_migrations/`, then
// rename the generated `tableName` column getters of pending_sync_changes to
// `targetTableName`, which clash with `Table.tableName`) and adds a
// `v20 -> v21` test here.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';

import 'generated_migrations/schema.dart';

/// The current schema version.
const latest = AppDatabase.currentSchemaVersion;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  Future<List<String>> triggerNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'trigger'")
        .get();
    return rows.map((r) => r.read<String>('name')).toList()..sort();
  }

  Future<Map<String, Object?>> row(
    AppDatabase db,
    String table,
    String id,
  ) async {
    final result = await db
        .customSelect(
          'SELECT * FROM $table WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return result.data;
  }

  Future<List<String>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info("$table")').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  group('v$latest baseline', () {
    test('the schema snapshots end at the current version', () {
      expect(GeneratedHelper.versions.last, latest);
      expect(latest, AppDatabase.minimumSchemaVersion);
    });

    test('a new database matches the v$latest snapshot', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.validateDatabaseSchema();
      await db.close();
    });

    test('opening a v$latest database keeps its schema', () async {
      final schema = await verifier.schemaAt(latest);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);
      await db.close();
    });

    test('a new database has the sync and personal balance triggers', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final triggers = await triggerNames(db);
      for (final table in AppDatabase.syncedTables) {
        for (final action in ['insert', 'update', 'delete']) {
          expect(triggers, contains('${table}_${action}_trigger'));
        }
      }
      for (final name in [
        'transactions_insert_personal_balance',
        'transactions_update_personal_balance',
        'transactions_delete_personal_balance',
        'accounts_insert_personal_balance',
        'accounts_update_personal_balance',
      ]) {
        expect(triggers, contains(name));
      }
      await db.close();
    });

    test('accounts are shared until they get an owner; then the trigger '
        'keeps the shared balance', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customStatement(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        "is_closed, on_budget) VALUES ('a1', 'Main', 'checking', 'USD', "
        '5000, 0, 1)',
      );
      final account = await row(db, 'accounts', 'a1');
      expect(account['owner_id'], isNull);
      expect(account['shared_balance'], isNull);
      expect(
        await columns(db, 'accounts'),
        containsAll(['owner_id', 'shared_balance']),
      );

      final member = await db.accountsDao.localMemberId();
      await db.customStatement(
        "UPDATE accounts SET owner_id = ?, on_budget = 0 WHERE id = 'a1'",
        [member],
      );
      expect((await row(db, 'accounts', 'a1'))['shared_balance'], 5000);
      await db.close();
    });
  });

  group('unversioned indexes', () {
    // Pure performance indexes are created on open (no schema version
    // bump): change files keep the schema version, so a phone that has not
    // been updated yet still applies them.
    test('a v20 database gets the split-parent index on open', () async {
      final schema = await verifier.schemaAt(20);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      final indexes = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      expect(
        indexes.map((r) => r.read<String>('name')),
        contains(AppDatabase.splitParentIndex),
      );
      // The split-parent lookups use it.
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT 1 FROM transactions c '
            "WHERE c.parent_transaction_id = 'x' AND c.is_deleted = 0",
          )
          .get();
      expect(
        plan.map((r) => r.data['detail']).join(' '),
        contains(AppDatabase.splitParentIndex),
      );
      // Opening again is a no-op.
      await db.createUnversionedIndexes();
      await db.close();
    });
  });
}
