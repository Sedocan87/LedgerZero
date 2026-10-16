// Schema migration tests (drift schema verifier).
//
// Schemas live in drift_schemas/ (dumped with `dart run drift_dev schema dump
// lib/data/database/database.dart drift_schemas/`); the helpers in
// generated_migrations/ come from
// `dart run drift_dev schema generate
//  drift_schemas/ test/database/generated_migrations/` (then rename the
// generated `tableName` column getters of sync_log / pending_sync_changes to
// `targetTableName`, which clash with `Table.tableName`).
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';

import '../domain/services/ledger_test_helpers.dart';
import '../helpers/test_database.dart';
import 'generated_migrations/schema.dart';

/// The schema version the app migrates to.
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

  group('structure', () {
    for (final from in GeneratedHelper.versions.where((v) => v < latest)) {
      test(
        'upgrade from v$from to v$latest matches the current schema',
        () async {
          final schema = await verifier.schemaAt(from);
          final db = AppDatabase(schema.newConnection());
          await verifier.migrateAndValidate(db, latest);

          // The v17 step (re)creates the sync triggers for every synced
          // table. The schema snapshots carry no triggers, so an upgrade
          // that starts at v17 or later has none to check (the v18 step
          // only drops the unused parsing_rules table).
          if (from >= 17) {
            await db.close();
            return;
          }
          final triggers = await triggerNames(db);
          for (final table in AppDatabase.syncedTables) {
            for (final action in ['insert', 'update', 'delete']) {
              expect(triggers, contains('${table}_${action}_trigger'));
            }
          }
          await db.close();
        },
      );
    }

    test('fresh install creates v$latest with triggers', () async {
      final schema = await verifier.schemaAt(latest);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);
      await db.close();
    });
  });

  group('data conversion v14 -> v$latest', () {
    late AppDatabase db;

    setUp(() async {
      final schema = await verifier.schemaAt(14);
      final raw = schema.rawDatabase;
      raw.execute(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        'current_balance, is_closed, created_at, updated_at) VALUES '
        "('a1', 'Checking', 'checking', 'EUR', 12.345, 999.99, 0, "
        "'2024-05-03T10:00:00.000 +02:00', '2024-05-03T08:00:00.000Z'), "
        "('a2', 'Card', 'credit', 'USD', -0.1, 0, 0, NULL, NULL)",
      );
      raw.execute(
        'INSERT INTO category_groups (id, name, sort_order, created_at) '
        "VALUES ('g1', 'Group', 0, NULL)",
      );
      raw.execute(
        'INSERT INTO categories (id, name, category_group_id, is_hidden, '
        'target_amount, target_date) VALUES '
        "('c1', 'Food', 'g1', 0, 250.5, '2024-12-31T00:00:00.000 -05:00'), "
        "('c2', 'Rent', 'g1', 0, NULL, NULL)",
      );
      raw.execute(
        'INSERT INTO transactions (id, account_id, date, amount, category_id, '
        'cleared, approved, is_deleted, created_at) VALUES '
        "('t1', 'a1', '2024-05-03T00:00:00.000 +02:00', 0.1, 'c1', 0, 1, 0, "
        "'2024-05-03T23:30:00.000 +02:00'), "
        "('t2', 'a1', '2024-05-02T22:00:00.000Z', -12.345, 'c1', 0, 1, 0, NULL), "
        "('t3', 'a1', '2024-05-04T00:00:00.000Z', -0.005, NULL, 0, 1, 0, NULL), "
        "('t4', 'a1', '2024-05-05T12:34:00.000 +02:00', 19.99, NULL, 0, 1, 0, NULL), "
        "('t5', 'a2', '2024-05-05T00:00:00.000 +02:00', -2.675, NULL, 0, 1, 0, NULL)",
      );
      raw.execute(
        'INSERT INTO budgets (id, category_id, month, budgeted, activity, '
        "available) VALUES ('b1', 'c1', '2024-05', 0.3, -0.3, 0.0)",
      );
      raw.execute(
        'INSERT INTO scheduled_transactions (id, account_id, amount, '
        'frequency, next_date, auto_approve) VALUES '
        "('s1', 'a1', -45.67, 'monthly', '2024-06-01T00:00:00.000 +02:00', 0)",
      );
      raw.execute(
        'INSERT INTO budget_templates (id, name, data, created_at) VALUES '
        "('bt1', 'Base', '{\"c1\": 12.5, \"c2\": 0.1}', "
        "'2024-05-03T10:00:00.000')",
      );
      raw.execute(
        'INSERT INTO rules (id, name, priority, is_active, match_logic, '
        'conditions, actions, created_at, updated_at) VALUES '
        "('r1', 'Small', 0, 1, 'and', "
        "'[{\"type\":\"amount\",\"operator\":\"lessThan\",\"value\":\"5.00\"},"
        "{\"type\":\"payee\",\"operator\":\"contains\",\"value\":\"5.00\"}]', "
        "'[]', '2024-05-03T10:00:00.000', '2024-05-03T10:00:00.000')",
      );
      raw.execute('DELETE FROM pending_sync_changes');

      db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);
    });

    tearDown(() => db.close());

    test('REAL amounts become INTEGER minor units', () async {
      expect((await row(db, 'accounts', 'a1'))['starting_balance'], 1235);
      expect((await row(db, 'accounts', 'a2'))['starting_balance'], -10);
      expect((await row(db, 'transactions', 't1'))['amount'], 10);
      expect((await row(db, 'transactions', 't2'))['amount'], -1235);
      expect((await row(db, 'transactions', 't3'))['amount'], -1);
      expect((await row(db, 'transactions', 't4'))['amount'], 1999);
      expect((await row(db, 'budgets', 'b1'))['budgeted'], 30);
      expect((await row(db, 'categories', 'c1'))['target_amount'], 25050);
      expect((await row(db, 'categories', 'c2'))['target_amount'], isNull);
      expect((await row(db, 'scheduled_transactions', 's1'))['amount'], -4567);

      final typeRows = await db
          .customSelect('SELECT DISTINCT typeof(amount) AS t FROM transactions')
          .get();
      expect(typeRows.map((r) => r.read<String>('t')), ['integer']);
    });

    test('dead columns are dropped and updated_at added', () async {
      expect(await columns(db, 'accounts'), isNot(contains('current_balance')));
      expect(await columns(db, 'budgets'), isNot(contains('activity')));
      expect(await columns(db, 'budgets'), isNot(contains('available')));
      for (final table in [
        'categories',
        'category_groups',
        'payees',
        'scheduled_transactions',
        'budget_templates',
        'import_profiles',
      ]) {
        expect(await columns(db, table), contains('updated_at'), reason: table);
      }
    });

    test('JSON amounts are converted to minor units', () async {
      final template = await row(db, 'budget_templates', 'bt1');
      expect(jsonDecode(template['data'] as String), {'c1': 1250, 'c2': 10});

      final rule = await row(db, 'rules', 'r1');
      final conditions = jsonDecode(rule['conditions'] as String) as List;
      expect(conditions[0]['value'], '500');
      expect(conditions[0]['amountUnit'], 'minor');
      // Non-amount conditions are untouched.
      expect(conditions[1]['value'], '5.00');
      expect(conditions[1].containsKey('amountUnit'), isFalse);
    });

    test('dates become UTC; calendar days keep the picked day', () async {
      final t1 = await row(db, 'transactions', 't1');
      expect(t1['date'], '2024-05-03T00:00:00.000Z');
      expect(t1['created_at'], '2024-05-03T21:30:00.000Z');
      final t4 = await row(db, 'transactions', 't4');
      expect(t4['date'], '2024-05-05T00:00:00.000Z');
      final t3 = await row(db, 'transactions', 't3');
      expect(t3['date'], '2024-05-04T00:00:00.000Z');
      final c1 = await row(db, 'categories', 'c1');
      expect(c1['target_date'], '2024-12-31T00:00:00.000Z');
      final s1 = await row(db, 'scheduled_transactions', 's1');
      expect(s1['next_date'], '2024-06-01T00:00:00.000Z');
      final a1 = await row(db, 'accounts', 'a1');
      expect(a1['created_at'], '2024-05-03T08:00:00.000Z');
      expect(a1['updated_at'], '2024-05-03T08:00:00.000Z');

      // Drift reads them back as UTC DateTimes.
      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('t1'))).getSingle();
      expect(tx.date, DateTime.utc(2024, 5, 3));
      expect(tx.date.isUtc, isTrue);
    });

    test(
      'migration does not enqueue sync changes; triggers work after',
      () async {
        final before = await db
            .customSelect('SELECT COUNT(*) AS c FROM pending_sync_changes')
            .getSingle();
        expect(before.read<int>('c'), 0);

        await db.customStatement(
          "UPDATE transactions SET memo = 'x' WHERE id = 't1'",
        );
        final after = await db
            .customSelect(
              "SELECT * FROM pending_sync_changes WHERE record_id = 't1'",
            )
            .get();
        expect(after, hasLength(1));
        expect(after.single.read<String>('action'), 'UPDATE');
      },
    );

    test('computed balance uses the converted amounts', () async {
      final balances = await db.accountsDao.getAccountBalances();
      // 12.35 + 0.10 - 12.35 - 0.01 + 19.99 = 20.08
      expect(balances['a1'], 1235 + 10 - 1235 - 1 + 1999);
      expect(balances['a2'], -10 - 268);
    });

    test('the budget invariant holds on the upgraded data', () async {
      await expectLedgerInvariant(TestDatabase.wrap(db), DateTime.utc(2024, 5));
    });
  });

  group('data conversion v1 -> v$latest', () {
    test('old rows survive the full upgrade chain', () async {
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        'current_balance, is_closed) VALUES '
        "('a1', 'Old', 'savings', 'USD', 100.5, 100.5, 0)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO payees (id, name) VALUES ('p1', 'Shop')",
      );
      schema.rawDatabase.execute(
        'INSERT INTO transactions (id, account_id, date, amount, payee_id, '
        'cleared, approved) VALUES '
        "('t1', 'a1', '2023-01-15T00:00:00.000 +01:00', -7.3, 'p1', 1, 1)",
      );
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      final account = await row(db, 'accounts', 'a1');
      expect(account['starting_balance'], 10050);
      final tx = await row(db, 'transactions', 't1');
      expect(tx['amount'], -730);
      expect(tx['is_deleted'], 0);
      expect(tx['parent_transaction_id'], isNull);
      expect(tx['date'], '2023-01-15T00:00:00.000Z');
      final payee = await row(db, 'payees', 'p1');
      expect(payee['default_account_id'], isNull);
      expect(payee['is_favorite'], 0);

      expect(await db.accountsDao.getAccountBalance('a1'), 10050 - 730);
      await expectLedgerInvariant(TestDatabase.wrap(db), DateTime.utc(2023));
      await db.close();
    });
  });

  // A ledger in the minor-unit format of v15/v16 (transfer pair, split with
  // two lines, income, a soft-deleted row, budgets) must come out of the
  // upgrade with the same balances, budgets and TBB.
  for (final from in [15, 16, 17]) {
    test('data conversion v$from -> v$latest keeps balances, budgets and TBB', () async {
      final schema = await verifier.schemaAt(from);
      final raw = schema.rawDatabase;
      raw.execute(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        "is_closed) VALUES ('a1', 'Checking', 'checking', 'EUR', 100000, 0), "
        "('a2', 'Savings', 'savings', 'EUR', 0, 0)",
      );
      raw.execute(
        "INSERT INTO category_groups (id, name, sort_order) VALUES ('g1', 'Bills', 0)",
      );
      raw.execute(
        'INSERT INTO categories (id, name, category_group_id, is_hidden) VALUES '
        "('c1', 'Food', 'g1', 0), ('c2', 'Rent', 'g1', 0)",
      );
      raw.execute(
        'INSERT INTO transactions (id, account_id, date, amount, category_id, '
        'transfer_account_id, transfer_transaction_id, parent_transaction_id, '
        'cleared, approved, is_deleted) VALUES '
        "('t1', 'a1', '2024-03-01T00:00:00.000Z', 250000, NULL, NULL, NULL, NULL, 1, 1, 0), "
        "('t2', 'a1', '2024-03-03T00:00:00.000Z', -12345, 'c1', NULL, NULL, NULL, 0, 1, 0), "
        "('out', 'a1', '2024-03-05T00:00:00.000Z', -50000, NULL, 'a2', 'in', NULL, 0, 1, 0), "
        "('in', 'a2', '2024-03-05T00:00:00.000Z', 50000, NULL, 'a1', 'out', NULL, 0, 1, 0), "
        "('sp', 'a1', '2024-03-06T00:00:00.000Z', -9000, NULL, NULL, NULL, NULL, 0, 1, 0), "
        "('sp1', 'a1', '2024-03-06T00:00:00.000Z', -6000, 'c1', NULL, NULL, 'sp', 0, 1, 0), "
        "('sp2', 'a1', '2024-03-06T00:00:00.000Z', -3000, 'c2', NULL, NULL, 'sp', 0, 1, 0), "
        "('gone', 'a1', '2024-03-07T00:00:00.000Z', -99999, 'c1', NULL, NULL, NULL, 0, 1, 1)",
      );
      raw.execute(
        'INSERT INTO budgets (id, category_id, month, budgeted) VALUES '
        "('b1', 'c1', '2024-03', 30000), ('b2', 'c2', '2024-03', 10000)",
      );
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      final t = TestDatabase.wrap(db);
      final march = DateTime.utc(2024, 3);
      final balances = await db.accountsDao.getAccountBalances();
      expect(balances['a1'], 100000 + 250000 - 12345 - 50000 - 9000);
      expect(balances['a2'], 50000);
      expect(await t.budgeting.calculateTBB(march), 100000 + 250000 - 40000);
      expect(
        await t.budgeting.calculateCategoryAvailable('c1', march),
        30000 - 12345 - 6000,
      );
      expect(
        await t.budgeting.calculateCategoryAvailable('c2', march),
        10000 - 3000,
      );
      final out = await row(db, 'transactions', 'out');
      expect(out['transfer_transaction_id'], 'in');
      expect(
        (await row(db, 'transactions', 'sp1'))['parent_transaction_id'],
        'sp',
      );
      expect((await row(db, 'transactions', 'gone'))['is_deleted'], 1);
      await expectLedgerInvariant(t, march);
      await db.close();
    });
  }

  group('v15 -> v16', () {
    test('scheduled transactions gain memo and anchor day', () async {
      final schema = await verifier.schemaAt(15);
      schema.rawDatabase.execute(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        "is_closed) VALUES ('a1', 'Main', 'checking', 'USD', 0, 0)",
      );
      schema.rawDatabase.execute(
        'INSERT INTO scheduled_transactions (id, account_id, amount, '
        'frequency, next_date, auto_approve) VALUES '
        "('s1', 'a1', -4567, 'monthly', '2024-01-31T00:00:00.000Z', 0)",
      );
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      final s1 = await row(db, 'scheduled_transactions', 's1');
      expect(s1['amount'], -4567);
      expect(s1['memo'], isNull);
      expect(s1['anchor_day'], isNull);
      await db.close();
    });
  });

  group('v16 -> v17', () {
    test('sync format v2 bookkeeping replaces the v1 log', () async {
      final schema = await verifier.schemaAt(16);
      final raw = schema.rawDatabase;
      raw.execute(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        "is_closed) VALUES ('a1', 'Main', 'checking', 'USD', 0, 0)",
      );
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, latest);

      // v1 pending changes (from the insert above) are discarded.
      final pending = await db
          .customSelect('SELECT COUNT(*) AS c FROM pending_sync_changes')
          .getSingle();
      expect(pending.read<int>('c'), 0);
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names, isNot(contains('sync_log')));
      expect(
        names,
        containsAll(<String>[
          'sync_device_progress',
          'sync_kv',
          'sync_row_versions',
          'sync_conflicts',
          'sync_quarantine',
          'sync_applying',
        ]),
      );

      // New triggers: capture changes and fill in updated_at.
      await db.customStatement(
        "UPDATE accounts SET name = 'Renamed' WHERE id = 'a1'",
      );
      final a1 = await row(db, 'accounts', 'a1');
      expect(a1['updated_at'], isNotNull);
      final captured = await db
          .customSelect('SELECT action FROM pending_sync_changes')
          .get();
      expect(captured.map((r) => r.read<String>('action')), ['UPDATE']);
      await db.close();
    });
  });

  group('v17 -> v18', () {
    test(
      'parsing_rules is dropped; parsing history and ledger data stay',
      () async {
        final schema = await verifier.schemaAt(17);
        final raw = schema.rawDatabase;
        raw.execute(
          'INSERT INTO accounts (id, name, type, currency, starting_balance, '
          "is_closed) VALUES ('a1', 'Main', 'checking', 'USD', 5000, 0)",
        );
        raw.execute(
          'INSERT INTO parsing_rules (id, keyword, category_id, payee_id, '
          "created_at) VALUES ('pr1', 'coffee', NULL, NULL, "
          "'2024-01-01T00:00:00.000Z')",
        );
        raw.execute(
          'INSERT INTO parsing_history (id, input, payee_id, category_id, '
          "created_at) VALUES ('ph1', 'coffee 3', NULL, NULL, "
          "'2024-01-01T00:00:00.000Z')",
        );
        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, latest);

        final tables = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
        final names = tables.map((r) => r.read<String>('name')).toSet();
        expect(names, isNot(contains('parsing_rules')));
        expect((await row(db, 'parsing_history', 'ph1'))['input'], 'coffee 3');
        expect((await db.accountsDao.getAccountBalances())['a1'], 5000);
        await db.close();
      },
    );
  });
}
