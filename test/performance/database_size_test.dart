// How large a realistic database gets, against the 25 MB that Android's
// cloud backup takes per app (above it, the backup silently stops). Prints
// the sizes; tagged `perf` (it writes ~45,000 rows).
//
//   flutter test --tags perf --run-skipped test/performance/database_size_test.dart
@Tags(['perf'])
library;

import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

/// Four years of a two-person household: ~25,000 transactions (splits and
/// transfers included) with payees, categories and memos, a budget per
/// category and month, schedules, rules, quick-add history, and the sync
/// bookkeeping of a phone that has synced a few thousand changes (a row
/// version per synced row, tombstones of the last 180 days, a few pending
/// changes and conflicts). The card-capture log is not in the database.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('lz_db_size_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  int sizeOf(File db) {
    var size = 0;
    for (final suffix in const ['', '-wal']) {
      final f = File('${db.path}$suffix');
      if (f.existsSync()) {
        size += f.lengthSync();
      }
    }
    return size;
  }

  test('a four-year two-person household fits in the 25 MB of Android '
      'backup', () async {
    final file = File(p.join(tmp.path, 'db.sqlite'));
    // Schema, seeded categories and triggers as the app creates them.
    final app = AppDatabase(NativeDatabase(file));
    await app.customSelect('SELECT 1').get();
    await app.close();

    final stats = _generate(file, years: 4, transactions: 25000);
    final before = sizeOf(file);

    final db = sqlite.sqlite3.open(file.path);
    db.execute('VACUUM');
    try {
      final rows = db.select(
        'SELECT name, SUM(pgsize) AS bytes FROM dbstat GROUP BY name '
        'ORDER BY bytes DESC LIMIT 25',
      );
      // ignore: avoid_print
      print(rows.map((r) => '${r['name']}: ${r['bytes']}').join('\n'));
    } on sqlite.SqliteException {
      // dbstat not compiled in.
    }
    db.close();
    final vacuumed = sizeOf(file);

    String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(2);
    // ignore: avoid_print
    print(
      'database size: $stats\n'
      '  without VACUUM: ${mb(before)} MB ($before bytes)\n'
      '  after VACUUM:   ${mb(vacuumed)} MB ($vacuumed bytes)\n'
      '  per transaction (after VACUUM): '
      '${(vacuumed / stats.transactions).toStringAsFixed(0)} bytes',
    );
    // Measured 2026-11-10: 19.5 MB as written, 18.6 MB after VACUUM
    // (about 780 bytes per transaction, indexes and sync bookkeeping
    // included), so the quota is reached at roughly 33,000 transactions.
    expect(before, lessThan(25 * 1024 * 1024));
  });
}

class _Stats {
  int transactions = 0;
  int payees = 0;
  int categories = 0;
  int budgets = 0;
  int rowVersions = 0;
  int tombstones = 0;
  int pending = 0;

  @override
  String toString() =>
      '$transactions transactions, $payees payees, $categories categories, '
      '$budgets budget rows, $rowVersions row versions ($tombstones '
      'tombstones), $pending pending changes';
}

_Stats _generate(File file, {required int years, required int transactions}) {
  final random = Random(42);
  const uuid = Uuid();
  final stats = _Stats();
  final db = sqlite.sqlite3.open(file.path);
  final me = uuid.v4();
  final partner = uuid.v4();
  final start = DateTime.utc(2022, 11, 1);
  final days = years * 365;
  String iso(DateTime d) => d.toIso8601String();
  String stamp(DateTime d) =>
      iso(d.add(Duration(seconds: random.nextInt(86400))));
  final versions = <(String, String, DateTime)>[];

  // Rows written as if a change file was applied: the triggers do
  // nothing, the sync bookkeeping is filled in below like after sync.
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('BEGIN');
  db.execute('INSERT INTO sync_applying (id) VALUES (1)');

  final accounts = <String>[];
  for (final (name, type, owner) in [
    ('Joint checking', 'checking', null),
    ('Savings', 'savings', null),
    ('Credit card A', 'credit', null),
    ('Credit card B', 'credit', null),
    ('Cash', 'cash', null),
    ('Holiday savings', 'savings', null),
    ('My account', 'checking', me),
    ('Partner account', 'checking', partner),
  ]) {
    final id = uuid.v4();
    accounts.add(id);
    final t = start.subtract(const Duration(days: 1));
    db.execute(
      'INSERT INTO accounts (id, name, type, currency, starting_balance, '
      'owner_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, name, type, 'EUR', 150000, owner, iso(t), stamp(t)],
    );
    versions.add(('accounts', id, t));
  }

  // Seeded categories plus the household's own (about 60 in all).
  final groups = [
    for (final r in db.select('SELECT id FROM category_groups')) r['id'],
  ];
  for (var i = 0; i < 45; i++) {
    final id = uuid.v4();
    db.execute(
      'INSERT INTO categories (id, name, category_group_id, sort_order, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        id,
        'Category ${i + 1}',
        groups[i % groups.length],
        i,
        iso(start),
        stamp(start),
      ],
    );
  }
  final categories = [
    for (final r in db.select('SELECT id FROM categories')) r['id'] as String,
  ];
  stats.categories = categories.length;
  for (final c in categories) {
    versions.add(('categories', c, start));
  }
  for (final g in groups) {
    versions.add(('category_groups', g as String, start));
  }

  final payees = <String>[];
  for (var i = 0; i < 700; i++) {
    final id = uuid.v4();
    payees.add(id);
    final t = start.add(Duration(days: random.nextInt(days)));
    db.execute(
      'INSERT INTO payees (id, name, auto_category_id, created_at, '
      'updated_at) VALUES (?, ?, ?, ?, ?)',
      [
        id,
        'Payee name ${i + 1} GmbH',
        categories[i % categories.length],
        iso(t),
        stamp(t),
      ],
    );
    versions.add(('payees', id, t));
  }
  stats.payees = payees.length;

  const memos = [
    'Weekly groceries',
    'Birthday present for Anna',
    'Fuel',
    'Monthly rent',
    'Dinner with friends',
    'School trip',
    'Pharmacy',
    'Car insurance (yearly)',
  ];
  final insertTx = db.prepare(
    'INSERT INTO transactions (id, account_id, date, amount, payee_id, '
    'category_id, memo, cleared, approved, transfer_account_id, '
    'transfer_transaction_id, parent_transaction_id, created_at, '
    'updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?)',
  );
  var count = 0;
  void tx({
    required String id,
    required String account,
    required DateTime date,
    required int amount,
    String? payee,
    String? category,
    String? memo,
    String? transferAccount,
    String? transferId,
    String? parent,
  }) {
    insertTx.execute([
      id,
      account,
      iso(date),
      amount,
      payee,
      category,
      memo,
      random.nextInt(3),
      transferAccount,
      transferId,
      parent,
      stamp(date),
      stamp(date),
    ]);
    versions.add(('transactions', id, date));
    count++;
  }

  while (count < transactions) {
    final date = start.add(Duration(days: random.nextInt(days)));
    final account = accounts[random.nextInt(accounts.length)];
    final memo = random.nextInt(10) < 4
        ? memos[random.nextInt(memos.length)]
        : null;
    final kind = random.nextInt(100);
    if (kind < 4) {
      // Transfer: two legs.
      final other = accounts[random.nextInt(accounts.length)];
      final a = uuid.v4();
      final b = uuid.v4();
      final amount = (random.nextInt(50000) + 1000);
      tx(
        id: a,
        account: account,
        date: date,
        amount: -amount,
        transferAccount: other,
        transferId: b,
        memo: memo,
      );
      tx(
        id: b,
        account: other,
        date: date,
        amount: amount,
        transferAccount: account,
        transferId: a,
        memo: memo,
      );
    } else if (kind < 12) {
      // Split: a parent and two or three lines.
      final parent = uuid.v4();
      final parts = 2 + random.nextInt(2);
      var total = 0;
      final amounts = [
        for (var i = 0; i < parts; i++) -(random.nextInt(8000) + 200),
      ];
      for (final a in amounts) {
        total += a;
      }
      tx(
        id: parent,
        account: account,
        date: date,
        amount: total,
        payee: payees[random.nextInt(payees.length)],
        memo: memo,
      );
      for (final a in amounts) {
        tx(
          id: uuid.v4(),
          account: account,
          date: date,
          amount: a,
          category: categories[random.nextInt(categories.length)],
          parent: parent,
        );
      }
    } else {
      final income = random.nextInt(30) == 0;
      tx(
        id: uuid.v4(),
        account: account,
        date: date,
        amount: income
            ? random.nextInt(300000) + 100000
            : -(random.nextInt(15000) + 150),
        payee: payees[random.nextInt(payees.length)],
        category: income ? null : categories[random.nextInt(categories.length)],
        memo: memo,
      );
    }
  }
  insertTx.close();
  stats.transactions = count;

  // A budget row per category and month.
  for (var m = 0; m < years * 12; m++) {
    final month = DateTime.utc(start.year, start.month + m);
    final key =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}';
    for (final c in categories) {
      final id = uuid.v4();
      db.execute(
        'INSERT INTO budgets (id, category_id, month, budgeted, created_at, '
        'updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [id, c, key, random.nextInt(50000), iso(month), stamp(month)],
      );
      versions.add(('budgets', id, month));
      stats.budgets++;
    }
  }

  for (var i = 0; i < 30; i++) {
    final id = uuid.v4();
    db.execute(
      'INSERT INTO scheduled_transactions (id, account_id, payee_id, '
      'category_id, amount, frequency, interval, next_date, memo, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)',
      [
        id,
        accounts[i % accounts.length],
        payees[i],
        categories[i],
        -9900,
        'monthly',
        iso(start.add(Duration(days: days))),
        'Standing order',
        iso(start),
        stamp(start),
      ],
    );
    versions.add(('scheduled_transactions', id, start));
  }
  for (var i = 0; i < 3000; i++) {
    final t = start.add(Duration(days: random.nextInt(days)));
    db.execute(
      'INSERT INTO parsing_history (id, input, payee_id, category_id, '
      'created_at) VALUES (?, ?, ?, ?, ?)',
      [
        uuid.v4(),
        '12.50 bakery yesterday',
        payees[i % payees.length],
        categories[i % categories.length],
        iso(t),
      ],
    );
  }

  db.execute('DELETE FROM sync_applying');

  // Sync bookkeeping of a phone that synced all of this: one row version
  // per synced row (half written here, half received), tombstones of rows
  // deleted in the last 180 days, two devices' progress, a few conflicts,
  // and the changes not uploaded yet.
  final insertVersion = db.prepare(
    'INSERT OR REPLACE INTO sync_row_versions (sync_table, row_id, version, '
    'device_id, deleted, sequence) VALUES (?, ?, ?, ?, ?, ?)',
  );
  final devices = [uuid.v4(), uuid.v4()];
  var sequence = 0;
  for (final (table, id, t) in versions) {
    final mine = random.nextBool();
    insertVersion.execute([
      table,
      id,
      t.microsecondsSinceEpoch,
      devices[mine ? 0 : 1],
      0,
      mine ? ++sequence ~/ 20 : null,
    ]);
    stats.rowVersions++;
  }
  final recent = start.add(Duration(days: days - 180));
  for (var i = 0; i < 3000; i++) {
    final t = recent.add(Duration(days: random.nextInt(180)));
    insertVersion.execute([
      'transactions',
      uuid.v4(),
      t.microsecondsSinceEpoch,
      devices[random.nextInt(2)],
      1,
      null,
    ]);
    stats.rowVersions++;
    stats.tombstones++;
  }
  insertVersion.close();
  for (final d in devices) {
    db.execute(
      'INSERT INTO sync_device_progress (device_id, last_sequence) '
      'VALUES (?, ?)',
      [d, sequence ~/ 20],
    );
  }
  final now = iso(start.add(Duration(days: days)));
  for (var i = 0; i < 40; i++) {
    db.execute(
      'INSERT INTO sync_conflicts (sync_table, row_id, local_snapshot, '
      'remote_snapshot, remote_device_id, resolved_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        'transactions',
        uuid.v4(),
        '{"id":"${uuid.v4()}","account_id":"${accounts[0]}","amount":-1250,'
            '"memo":"Weekly groceries","date":"$now"}',
        '{"id":"${uuid.v4()}","account_id":"${accounts[0]}","amount":-1350,'
            '"memo":"Weekly groceries","date":"$now"}',
        devices[1],
        now,
      ],
    );
  }
  for (var i = 0; i < 300; i++) {
    db.execute(
      'INSERT INTO pending_sync_changes (table_name, record_id, action, '
      'changed_at) VALUES (?, ?, ?, ?)',
      ['transactions', uuid.v4(), 'UPDATE', now],
    );
    stats.pending++;
  }
  db.execute('COMMIT');
  db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
  db.close();
  return stats;
}
