// Multi-device sync simulation: real in-memory databases (SQLCipher), real
// engines, a fake in-memory cloud folder. See docs/SYNC_ARCHITECTURE.md.
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart'
    hide ScheduledTransaction;
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/sync/format/sync_change.dart';
import 'package:ledger_zero/services/sync/format/sync_file_codec.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/format/sync_manifest.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/services/sync/sync_device_id.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/sync_local_state.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/sync_simulation.dart';
import '../../helpers/test_database.dart';

const passphrase = 'correct horse battery staple';

class _SilentNotifications extends Fake implements NotificationService {
  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {}

  @override
  Future<void> cancelNotification(int id) async {}
}

void main() {
  late FakeSyncFolder folder;
  final devices = <SimDevice>[];

  Future<SimDevice> device({
    SyncEngineConfig? config,
    QueryExecutor? executor,
    Random? shuffle,
    DateTime Function()? clock,
  }) async {
    final d = await SimDevice.create(
      folder,
      config: config,
      executor: executor,
      shuffle: shuffle,
      clock: clock,
    );
    devices.add(d);
    return d;
  }

  /// First device creates the folder, the others join.
  Future<void> connect(List<SimDevice> list) async {
    await list.first.engine.createSyncFolder(passphrase);
    for (final d in list.skip(1)) {
      await d.engine.joinSyncFolder(passphrase);
    }
  }

  Future<void> expectConverged(List<SimDevice> list) async {
    final reference = await list.first.dump();
    for (final d in list.skip(1)) {
      expect(await d.dump(), reference, reason: 'device ${d.deviceId}');
    }
  }

  Future<String> addAccount(SimDevice d, String id, String name) async {
    await d.exec(
      'INSERT INTO accounts (id, name, type, currency, starting_balance, '
      "is_closed, created_at, updated_at) VALUES (?, ?, 'checking', 'USD', "
      "0, 0, '2025-01-01T00:00:00.000Z', '2025-01-01T00:00:00.000Z')",
      [id, name],
    );
    return id;
  }

  setUp(() {
    folder = FakeSyncFolder();
    devices.clear();
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
  });

  group('two devices', () {
    test('applied remote changes reach open stream queries', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'acc-a', 'From A');
      await addAccount(b, 'acc-a2', 'Local on B');

      // A screen on B watches the accounts table (Drift stream query).
      final seen = <int>[];
      final sub = b.db
          .select(b.db.accounts)
          .watch()
          .listen((rows) => seen.add(rows.length));
      await Future<void>.delayed(Duration.zero);
      await syncAll([a, b]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(seen.last, 2);
    });

    test('offline edits on both sides converge', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'acc-a', 'From A');
      await addAccount(b, 'acc-b', 'From B');
      await a.t!.addTransaction(id: 'tx-a', accountId: 'acc-a', amount: -1234);
      await b.t!.addTransaction(id: 'tx-b', accountId: 'acc-b', amount: 5678);

      await syncAll([a, b]);

      await expectConverged([a, b]);
      expect(await a.count('SELECT COUNT(*) FROM accounts'), 2);
      expect(await a.count('SELECT COUNT(*) FROM transactions'), 2);
    });

    test('same row edited on both: newer wins, loser recorded', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'x', 'Original');
      await syncAll([a, b]);

      await a.exec(
        "UPDATE accounts SET name = 'A edit', "
        "updated_at = '2030-01-01T00:00:00.000Z' WHERE id = 'x'",
      );
      await b.exec(
        "UPDATE accounts SET name = 'B edit', "
        "updated_at = '2030-01-02T00:00:00.000Z' WHERE id = 'x'",
      );
      await syncAll([a, b]);

      await expectConverged([a, b]);
      final name = (await a.rows(
        "SELECT name FROM accounts WHERE id='x'",
      )).single['name'];
      expect(name, 'B edit');
      final conflicts = await a.db.syncDao.getConflicts();
      expect(conflicts, hasLength(1));
      expect(conflicts.single.localSnapshot, contains('A edit'));
      expect(conflicts.single.remoteSnapshot, contains('B edit'));
      expect(await b.db.syncDao.getConflicts(), isEmpty);

      // "Keep mine" re-applies A's version everywhere, without a new
      // conflict on B (B had seen nothing newer).
      await SyncConflictResolver(a.db).keepMine(conflicts.single.id);
      await syncAll([a, b]);
      await expectConverged([a, b]);
      expect(
        (await b.rows("SELECT name FROM accounts WHERE id='x'")).single['name'],
        'A edit',
      );
      expect(await a.db.syncDao.getConflicts(), isEmpty);
      expect(await b.db.syncDao.getConflicts(), isEmpty);
    });

    test('a pending local change does not win automatically', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'x', 'Original');
      await syncAll([a, b]);
      // B edits later (newer) and syncs; A edits earlier but has not synced.
      await b.exec(
        "UPDATE accounts SET name = 'B newer', "
        "updated_at = '2031-01-01T00:00:00.000Z' WHERE id = 'x'",
      );
      await b.sync();
      await a.exec(
        "UPDATE accounts SET name = 'A older', "
        "updated_at = '2030-01-01T00:00:00.000Z' WHERE id = 'x'",
      );
      await syncAll([a, b]);
      await expectConverged([a, b]);
      expect(
        (await a.rows("SELECT name FROM accounts WHERE id='x'")).single['name'],
        'B newer',
      );
    });

    test('delete newer than update: delete wins on both', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'x', 'Original');
      await syncAll([a, b]);

      await b.exec(
        "UPDATE accounts SET name = 'B edit', "
        "updated_at = '2025-06-01T00:00:00.000Z' WHERE id = 'x'",
      );
      await a.exec("DELETE FROM accounts WHERE id = 'x'"); // now (2026+)
      await b.sync();
      await a.sync();
      await b.sync();

      await expectConverged([a, b]);
      expect(await a.count('SELECT COUNT(*) FROM accounts'), 0);

      // A late copy of the older update does not resurrect the row.
      await a.db.syncDao.setProgress(b.deviceId, 0);
      await a.sync();
      expect(await a.count('SELECT COUNT(*) FROM accounts'), 0);
    });

    test('update newer than delete: update wins on both', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'x', 'Original');
      await syncAll([a, b]);

      await a.exec("DELETE FROM accounts WHERE id = 'x'");
      await b.exec(
        "UPDATE accounts SET name = 'B later', "
        "updated_at = '2099-01-01T00:00:00.000Z' WHERE id = 'x'",
      );
      await a.sync();
      await b.sync();
      await a.sync();

      await expectConverged([a, b]);
      expect(
        (await a.rows("SELECT name FROM accounts WHERE id='x'")).single['name'],
        'B later',
      );
    });

    test('echo prevention: replayed rows are not sent back', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await a.sync();
      await b.sync();
      await addAccount(a, 'x', 'Original');
      await a.t!.addTransaction(accountId: 'x', amount: 100);
      await a.sync();
      final report = await b.sync();
      expect(report.applied, greaterThanOrEqualTo(2));
      expect(await b.db.syncDao.pendingCount(), 0);
      final again = await b.sync();
      expect(again.uploaded, 0);
    });
  });

  group('natural keys and deterministic ids', () {
    test(
      'budgets for the same category and month converge to one row',
      () async {
        final a = await device();
        final b = await device();
        final groceries = await a.t!.categoryId('Groceries');
        final rent = await a.t!.categoryId('Rent/Mortgage');
        // Before the first sync: deterministic ids (WP2) ...
        await a.t!.budgeting.setCategoryBudgetedAmount(
          groceries,
          10000,
          DateTime.utc(2025, 5),
        );
        await b.t!.budgeting.setCategoryBudgetedAmount(
          groceries,
          25000,
          DateTime.utc(2025, 5),
        );
        // ... and rows with different ids for the same natural key.
        await a.exec(
          'INSERT INTO budgets (id, category_id, month, budgeted, created_at, '
          "updated_at) VALUES ('legacy-a', ?, '2025-06', 100, "
          "'2025-01-01T00:00:00.000Z', '2025-02-01T00:00:00.000Z')",
          [rent],
        );
        await b.exec(
          'INSERT INTO budgets (id, category_id, month, budgeted, created_at, '
          "updated_at) VALUES ('legacy-b', ?, '2025-06', 200, "
          "'2025-01-01T00:00:00.000Z', '2025-03-01T00:00:00.000Z')",
          [rent],
        );
        await a.exec(
          'INSERT INTO report_notes (id, date, note, created_at, updated_at) '
          "VALUES ('note-a', '2025-05', 'A', '2025-01-01T00:00:00.000Z', "
          "'2025-04-01T00:00:00.000Z')",
        );
        await b.exec(
          'INSERT INTO report_notes (id, date, note, created_at, updated_at) '
          "VALUES ('note-b', '2025-05', 'B', '2025-01-01T00:00:00.000Z', "
          "'2025-03-01T00:00:00.000Z')",
        );
        await connect([a, b]);
        await syncAll([a, b], rounds: 3);

        await expectConverged([a, b]);
        expect(
          await a.count("SELECT COUNT(*) FROM budgets WHERE month = '2025-05'"),
          1,
        );
        final june = await a.rows(
          "SELECT id, budgeted FROM budgets WHERE month = '2025-06'",
        );
        expect(june.single['id'], 'legacy-b'); // newer updated_at
        expect(june.single['budgeted'], 200);
        final notes = await a.rows('SELECT id, note FROM report_notes');
        expect(notes.single['id'], 'note-a');
      },
    );

    test('seeded default categories converge without duplicates', () async {
      final a = await device();
      final b = await device();
      final seeded = await a.count('SELECT COUNT(*) FROM categories');
      await connect([a, b]);
      await syncAll([a, b], rounds: 3);
      await expectConverged([a, b]);
      expect(await b.count('SELECT COUNT(*) FROM categories'), seeded);
      expect(await a.db.syncDao.getConflicts(), isEmpty);
      expect(await b.db.syncDao.getConflicts(), isEmpty);
    });

    test(
      'scheduled occurrences materialised on both devices converge',
      () async {
        final a = await device();
        final b = await device();
        await connect([a, b]);
        await addAccount(a, 'acc', 'Main');
        await a.t!.scheduledTransactions.createScheduledTransaction(
          ScheduledTransaction(
            id: 'rent',
            accountId: 'acc',
            amount: -90000,
            frequency: RecurrenceFrequency.monthly,
            nextDate: DateTime.utc(2025, 1, 1),
            memo: 'Rent',
          ),
        );
        await syncAll([a, b]);

        ScheduledTransactionService service(TestDatabase t) =>
            ScheduledTransactionService(
              t.scheduledTransactions,
              t.transactions,
              _SilentNotifications(),
              unitOfWork: t.unitOfWork,
            );
        final today = DateTime.utc(2025, 3, 15);
        expect(await service(a.t!).processDueTransactions(today: today), 3);
        expect(await service(b.t!).processDueTransactions(today: today), 3);
        await syncAll([a, b], rounds: 3);

        await expectConverged([a, b]);
        expect(await a.count('SELECT COUNT(*) FROM transactions'), 3);
      },
    );
  });

  group('atomicity and ordering', () {
    test('a transfer and a split arrive in one file', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await syncAll([a, b]);
      await addAccount(a, 'checking', 'Checking');
      await addAccount(a, 'savings', 'Savings');
      final service = TransactionService(
        transactionRepository: a.t!.transactions,
        payeeRepository: a.t!.payees,
        accountRepository: a.t!.accounts,
        undoService: UndoService(),
        unitOfWork: a.t!.unitOfWork,
      );
      final groceries = await a.t!.categoryId('Groceries');
      final dining = await a.t!.categoryId('Dining Out');
      await service.save(
        TransactionInput(
          accountId: 'checking',
          date: DateTime.utc(2025, 5, 1),
          amount: -5000,
          transferAccountId: 'savings',
        ),
      );
      await service.save(
        TransactionInput(
          accountId: 'checking',
          date: DateTime.utc(2025, 5, 2),
          amount: -3000,
          splits: [
            SplitLineInput(amount: -1000, categoryId: groceries),
            SplitLineInput(amount: -2000, categoryId: dining),
          ],
        ),
      );
      final before = folder.syncFiles(device: a.deviceId).length;
      await a.sync();
      final created = folder.syncFiles(device: a.deviceId);
      expect(created.length, before + 1);

      final key = (await SyncLocalState(a.db.syncDao).syncKey())!;
      final file = SyncFileCodec.decode(
        folder.single(created.last.name).bytes,
        key,
      );
      final txIds = file.changes
          .where((c) => c.table == 'transactions')
          .map((c) => c.id)
          .toSet();
      expect(txIds, hasLength(5)); // two legs + parent + two children

      await b.sync();
      await expectConverged([a, b]);
      expect(await b.count('SELECT COUNT(*) FROM transactions'), 5);
    });

    test('large change sets are cut between row families', () async {
      final a = await device(
        config: const SyncEngineConfig(
          kdfParams: fastKdf,
          maxChangesPerFile: 3,
        ),
      );
      final b = await device(
        config: const SyncEngineConfig(
          kdfParams: fastKdf,
          maxChangesPerFile: 3,
        ),
      );
      await connect([a, b]);
      await syncAll([a, b]);
      await addAccount(a, 'acc', 'Main');
      for (var i = 0; i < 4; i++) {
        await a.t!.addTransaction(id: 'p$i', accountId: 'acc', amount: -300);
        for (var j = 0; j < 2; j++) {
          await a.t!.addTransaction(
            id: 'p$i-c$j',
            accountId: 'acc',
            amount: -150,
            parentTransactionId: 'p$i',
          );
        }
      }
      final before = folder.syncFiles(device: a.deviceId).length;
      await a.sync();
      final names = folder.syncFiles(device: a.deviceId).skip(before);
      expect(names.length, greaterThan(1));
      final key = (await SyncLocalState(a.db.syncDao).syncKey())!;
      for (final n in names) {
        final file = SyncFileCodec.decode(folder.single(n.name).bytes, key);
        final ids = file.changes
            .where((c) => c.table == 'transactions')
            .map((c) => c.id)
            .toSet();
        for (final id in ids) {
          final family = id.split('-').first;
          expect(
            ids.where((x) => x.split('-').first == family),
            hasLength(3),
            reason: 'family $family split across files',
          );
        }
      }
      await b.sync();
      await expectConverged([a, b]);
    });

    test('250+ change files are listed across pages and all applied', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      for (var i = 0; i < 260; i++) {
        await a.exec(
          'INSERT INTO payees (id, name, is_favorite) VALUES (?, ?, 0)',
          ['p$i', 'Payee $i'],
        );
        await a.sync();
      }
      expect(folder.syncFiles(device: a.deviceId).length, greaterThan(250));
      b.transport.pageCalls = 0;
      await b.sync();
      expect(b.transport.pageCalls, greaterThanOrEqualTo(3));
      expect(await b.count('SELECT COUNT(*) FROM payees'), 260);
      await expectConverged([a, b]);
    });

    test('delayed, reordered and duplicated files', () async {
      final a = await device();
      final b = await device(shuffle: Random(7));
      await connect([a, b]);
      await syncAll([a, b]);
      for (var i = 0; i < 3; i++) {
        await addAccount(a, 'acc$i', 'Account $i');
        await a.sync();
      }
      final aFiles = folder.syncFiles(device: a.deviceId);
      final second = aFiles[aFiles.length - 2].name;
      folder.hidden.add(second);
      // A duplicated upload of the last file (same name, two ids).
      folder.add(aFiles.last.name, folder.named(aFiles.last.name).first.bytes);

      await b.sync();
      expect(await b.count('SELECT COUNT(*) FROM accounts'), 1);
      expect(await b.db.syncDao.getQuarantine(), isEmpty);

      folder.hidden.clear();
      await b.sync();
      expect(await b.count('SELECT COUNT(*) FROM accounts'), 3);
      await expectConverged([a, b]);
    });

    test('a file waits for the files it depends on (causal order)', () async {
      final a = await device();
      final b = await device();
      final c = await device();
      await connect([a, b, c]);
      await syncAll([a, b, c]);
      await addAccount(a, 'acc', 'Main');
      await a.sync();
      await c.sync();
      await c.exec(
        "INSERT INTO payees (id, name, is_favorite) VALUES ('shop', 'Shop', 0)",
      );
      await c.sync();
      final cFile = folder.syncFiles(device: c.deviceId).last.name;
      await a.sync(); // A learns about the payee ...
      await a.t!.addTransaction(
        id: 'tx',
        accountId: 'acc',
        amount: -100,
        payeeId: 'shop',
      );
      await a.sync(); // ... and uses it.

      folder.hidden.add(cFile);
      final report = await b.sync();
      expect(report.waitingDevices, greaterThan(0));
      expect(await b.count('SELECT COUNT(*) FROM transactions'), 0);

      folder.hidden.clear();
      await b.sync();
      final tx = await b.rows('SELECT payee_id FROM transactions');
      expect(tx.single['payee_id'], 'shop');
      await syncAll([a, b, c]);
      await expectConverged([a, b, c]);
    });

    test('a parent deleted on one device clears references on all', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'acc', 'Main');
      await a.exec(
        'INSERT INTO categories (id, name, is_hidden) '
        "VALUES ('extra', 'Extra', 0)",
      );
      await syncAll([a, b]);

      await a.exec("DELETE FROM categories WHERE id = 'extra'");
      await b.t!.addTransaction(
        id: 'tx',
        accountId: 'acc',
        amount: -100,
        categoryId: 'extra',
      );
      await a.exec(
        'INSERT INTO budgets (id, category_id, month, budgeted) '
        "VALUES ('x', ?, '2025-01', 5)",
        [await a.t!.categoryId('Groceries')],
      );
      await b.exec(
        'INSERT INTO budgets (id, category_id, month, budgeted) '
        "VALUES ('bx', 'extra', '2025-01', 7)",
      );
      await syncAll([a, b], rounds: 3);

      await expectConverged([a, b]);
      final tx = await a.rows('SELECT category_id FROM transactions');
      expect(tx.single['category_id'], isNull);
      expect(await a.count("SELECT COUNT(*) FROM budgets WHERE id='bx'"), 0);
    });
  });

  group('robustness', () {
    test(
      'a tampered file is quarantined and other devices still apply',
      () async {
        final a = await device();
        final b = await device();
        final c = await device();
        await connect([a, b, c]);
        await syncAll([a, b, c]);
        for (var i = 0; i < 3; i++) {
          await addAccount(a, 'a$i', 'A $i');
          await a.sync();
        }
        await addAccount(c, 'c0', 'C 0');
        await c.sync();

        final aFiles = folder.syncFiles(device: a.deviceId);
        final target = folder.single(aFiles[aFiles.length - 2].name);
        final original = Uint8List.fromList(target.bytes);
        target.bytes = Uint8List.fromList(original)
          ..[original.length - 5] ^= 0x01;

        final report = await b.sync();
        expect(report.newlyQuarantined, 1);
        final ids = (await b.rows(
          'SELECT id FROM accounts ORDER BY id',
        )).map((r) => r['id']).toList();
        expect(ids, ['a0', 'c0']);
        final q = await b.db.syncDao.getQuarantine();
        expect(q.single.filename, target.name);
        expect(q.single.reason, SyncEngine.reasonUnreadable);

        // Retries wait for the backoff ...
        await b.sync();
        expect((await b.db.syncDao.getQuarantine()).single.attempts, 1);
        // ... the file is repaired; a manual retry applies everything.
        target.bytes = original;
        await b.engine.retryQuarantined();
        await b.sync();
        expect(await b.db.syncDao.getQuarantine(), isEmpty);
        await syncAll([a, b, c]);
        await expectConverged([a, b, c]);
      },
    );

    test(
      'a truncated file is quarantined, then applied when complete',
      () async {
        final a = await device();
        final b = await device();
        await connect([a, b]);
        await syncAll([a, b]);
        await addAccount(a, 'x', 'X');
        await a.sync();
        final target = folder.single(
          folder.syncFiles(device: a.deviceId).last.name,
        );
        final original = target.bytes;
        target.bytes = Uint8List.sublistView(original, 0, original.length ~/ 2);
        await b.sync();
        expect(await b.db.syncDao.getQuarantine(), hasLength(1));
        target.bytes = original;
        await b.engine.retryQuarantined();
        await b.sync();
        expect(await b.count('SELECT COUNT(*) FROM accounts'), 1);
      },
    );

    test('an unreadable file is skipped after the last retry and repaired '
        'by a requested snapshot', () async {
      const config = SyncEngineConfig(
        kdfParams: fastKdf,
        maxQuarantineAttempts: 1,
      );
      final a = await device(config: config);
      final b = await device(config: config);
      await connect([a, b]);
      await syncAll([a, b]);
      await addAccount(a, 'lost', 'In the damaged file');
      await a.sync();
      await addAccount(a, 'later', 'In the next file');
      await a.sync();
      final aFiles = folder.syncFiles(device: a.deviceId);
      final damaged = folder.single(aFiles[aFiles.length - 2].name);
      damaged.bytes = Uint8List.fromList(damaged.bytes)
        ..[damaged.bytes.length - 3] ^= 0x01;

      await b.sync(); // quarantined (attempt 1 of 1)
      expect(await b.count('SELECT COUNT(*) FROM accounts'), 0);
      await b.sync(); // given up: skipped, snapshot requested
      expect(await b.db.syncDao.getQuarantine(), isEmpty);
      expect(
        await b.count("SELECT COUNT(*) FROM accounts WHERE id='later'"),
        1,
      );
      expect(await b.count("SELECT COUNT(*) FROM accounts WHERE id='lost'"), 0);
      final request = SyncFileName.request(a.deviceId, b.deviceId);
      expect(folder.names, contains(request));

      await a.sync(); // honours the request
      expect(folder.names, isNot(contains(request)));
      expect(folder.syncFiles(kind: SyncFileKind.snapshot), isNotEmpty);
      await b.sync(); // repaired from the snapshot
      expect(await b.count("SELECT COUNT(*) FROM accounts WHERE id='lost'"), 1);
      expect(await SyncLocalState(b.db.syncDao).needsSnapshot(), isEmpty);
      await syncAll([a, b]);
      await expectConverged([a, b]);
    });

    test('"skip file" asks the sender for a snapshot', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await syncAll([a, b]);
      await addAccount(a, 'x', 'X');
      await a.sync();
      final target = folder.single(
        folder.syncFiles(device: a.deviceId).last.name,
      );
      target.bytes = Uint8List.fromList(target.bytes)
        ..[target.bytes.length - 3] ^= 0x01;
      await b.sync();
      final q = (await b.db.syncDao.getQuarantine()).single;
      await b.engine.skipQuarantined(q.filename);
      await b.sync();
      expect(
        folder.names,
        contains(SyncFileName.request(a.deviceId, b.deviceId)),
      );
      await a.sync();
      await b.sync();
      expect(await b.count("SELECT COUNT(*) FROM accounts WHERE id='x'"), 1);
    });

    test(
      'files of an earlier sync folder are ignored, not quarantined',
      () async {
        var now = DateTime.utc(2030, 1, 1);
        final a = await device(clock: () => now);
        final b = await device(clock: () => now);
        await connect([a, b]);
        await addAccount(a, 'old-a', 'Old A');
        await addAccount(b, 'old-b', 'Old B');
        await syncAll([a, b]);
        final oldFiles = folder.syncFiles().map((f) => f.name).toSet();
        expect(oldFiles, isNotEmpty);

        // The user deletes only the manifest and sets the folder up again
        // with a new passphrase; the old change files stay behind.
        folder.files.removeWhere((_, f) => f.name == SyncFileName.manifest);
        now = now.add(const Duration(hours: 1));
        await a.engine.createSyncFolder('a brand new passphrase');
        await b.engine.joinSyncFolder('a brand new passphrase');
        await addAccount(a, 'new-a', 'New A');
        await syncAll([a, b], rounds: 3);

        await expectConverged([a, b]);
        expect(
          await b.count("SELECT COUNT(*) FROM accounts WHERE id='new-a'"),
          1,
        );
        final foreign = await b.db.syncDao.getQuarantine();
        expect(foreign, isNotEmpty);
        expect(
          foreign.every((q) => q.reason == SyncEngine.reasonForeign),
          isTrue,
        );
        expect(foreign.every((q) => oldFiles.contains(q.filename)), isTrue);
        expect(foreign.every((q) => q.deviceId == a.deviceId), isTrue);
        // Nothing waits: A's new files were applied past the old ones.
        expect((await b.sync()).waitingDevices, 0);

        // Each device lists the other's old files; both remove them.
        await b.engine.removeForeignFiles();
        await a.engine.removeForeignFiles();
        expect(await b.db.syncDao.getQuarantine(), isEmpty);
        expect(await a.db.syncDao.getQuarantine(), isEmpty);
        expect(folder.names.toSet().intersection(oldFiles), isEmpty);
        await syncAll([a, b]);
        await expectConverged([a, b]);
      },
    );

    test('a file with timestamps far in the future is reported', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await syncAll([a, b]);
      await a.exec(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        "is_closed, created_at, updated_at) VALUES ('f', 'F', 'checking', "
        "'USD', 0, 0, '2025-01-01T00:00:00.000Z', '2099-01-01T00:00:00.000Z')",
      );
      await a.sync();
      expect((await b.sync()).clockSkewSuspected, isTrue);
      expect((await b.sync()).clockSkewSuspected, isFalse);
    });

    test('lost preferences do not mint a new device id', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'x', 'X');
      await a.sync();
      expect(a.prefs.getString(SyncDeviceId.prefsKey), a.deviceId);

      // Preferences gone (new id minted), database kept, a change queued.
      a.prefs.values.clear();
      await addAccount(a, 'y', 'Y');
      final minted = const Uuid().v4();
      final engine = SyncEngine(
        db: a.db,
        transport: a.transport,
        deviceId: minted,
        outbox: a.outbox,
        prefs: a.prefs,
        config: a.config,
      );
      await engine.sync();

      expect(engine.deviceId, a.deviceId);
      expect(a.prefs.getString(SyncDeviceId.prefsKey), a.deviceId);
      expect(folder.syncFiles(device: minted), isEmpty);
      expect(folder.syncFiles(device: a.deviceId), hasLength(2));
      await syncAll([a, b]);
      expect(await b.count('SELECT COUNT(*) FROM accounts'), 2);
    });

    test('a wrong passphrase is rejected', () async {
      final a = await device();
      final b = await device();
      await a.engine.createSyncFolder(passphrase);
      expect(await b.engine.setupStatus(), SyncSetupStatus.needsPassphrase);
      await expectLater(
        b.engine.joinSyncFolder('not the passphrase'),
        throwsA(isA<WrongSyncPassphraseException>()),
      );
      expect((await b.sync()).setup, SyncSetupStatus.needsPassphrase);
      await expectLater(
        b.engine.createSyncFolder('another passphrase'),
        throwsA(isA<SyncFolderExistsException>()),
      );
      await b.engine.joinSyncFolder(passphrase);
      expect(await b.engine.setupStatus(), SyncSetupStatus.ready);
    });

    test('a file from a newer schema version is deferred', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await syncAll([a, b]);
      final key = (await SyncLocalState(a.db.syncDao).syncKey())!;
      final seq = await SyncLocalState(a.db.syncDao).ownSequence() + 1;
      final bytes = SyncFileCodec.encode(
        header: SyncFileHeader(
          kind: SyncFileKind.changes,
          deviceId: a.deviceId,
          sequence: seq,
          schemaVersion: AppDatabase.currentSchemaVersion + 1,
          changeCount: 1,
          maxVersion: 1,
          vector: const {},
          createdAt: DateTime.utc(2030),
        ),
        changes: const [
          SyncChange(
            table: 'payees',
            id: 'future',
            deleted: false,
            version: 1,
            deviceId: '00000000-0000-4000-8000-000000000000',
            row: {'id': 'future', 'name': 'Future', 'shiny_new': 1},
          ),
        ],
        key: key,
      );
      folder.add(SyncFileName.changes(a.deviceId, seq), bytes);

      final report = await b.sync();
      expect(report.newerSchemaPending, isTrue);
      expect(await b.count('SELECT COUNT(*) FROM payees'), 0);
      final q = await b.db.syncDao.getQuarantine();
      expect(q.single.reason, 'newer_schema');
      // Still deferred (not a failure) on the next run.
      expect((await b.sync()).newerSchemaPending, isTrue);
      expect((await b.db.syncDao.getQuarantine()).single.attempts, 0);
    });

    test('path-traversal and foreign file names are ignored', () async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      final evilBytes = Uint8List.fromList([1, 2, 3]);
      final id = a.deviceId;
      for (final name in [
        '../../${id}_000000000001.lzsync',
        '..\\${id}_000000000001.lzsync',
        '/tmp/${id}_000000000001.lzsync',
        'sub/${id}_000000000001.lzsync',
        '${id}_000000000001.lzsync/../../x',
        '${id.toUpperCase()}_000000000001.lzsync',
        '${id}_1.lzsync',
        'notes.txt',
        'old_123.json.gz',
      ]) {
        expect(SyncFileName.tryParse(name), isNull, reason: name);
        folder.add(name, evilBytes);
      }
      final report = await b.sync();
      expect(report.legacyFilesFound, isTrue);
      expect(await b.db.syncDao.getQuarantine(), isEmpty);
      final parent = b.dir.parent;
      expect(
        File('${parent.path}/${id}_000000000001.lzsync').existsSync(),
        isFalse,
      );
    });
  });

  group('snapshots, compaction and restore', () {
    test('a third device bootstraps from a snapshot and converges', () async {
      const config = SyncEngineConfig(
        kdfParams: fastKdf,
        snapshotEveryFiles: 3,
        compactAfter: Duration.zero,
      );
      final a = await device(config: config);
      final b = await device(config: config);
      await connect([a, b]);
      for (var i = 0; i < 4; i++) {
        await addAccount(a, 'a$i', 'A $i');
        await a.sync();
        await addAccount(b, 'b$i', 'B $i');
        await b.sync();
      }
      await a.exec("DELETE FROM accounts WHERE id = 'a0'");
      await syncAll([a, b], rounds: 2);

      final snapshots = folder.syncFiles(kind: SyncFileKind.snapshot);
      expect(snapshots, isNotEmpty);
      // Compaction removed own files covered by an own snapshot only.
      final aSnap = snapshots
          .where((s) => s.deviceId == a.deviceId)
          .map((s) => s.sequence)
          .reduce(max);
      final aFiles = folder.syncFiles(
        device: a.deviceId,
        kind: SyncFileKind.changes,
      );
      expect(aFiles.every((f) => f.sequence > aSnap), isTrue);

      final c = await device(config: config);
      await c.engine.joinSyncFolder(passphrase);
      c.transport.downloads = 0;
      await c.sync();
      await syncAll([a, b, c], rounds: 2);
      await expectConverged([a, b, c]);
      expect(await c.count("SELECT COUNT(*) FROM accounts WHERE id='a0'"), 0);
    });

    test('a restore triggers a rebootstrap that converges', () async {
      final tmp = await Directory.systemTemp.createTemp('lz_restore_');
      addTearDown(() => tmp.delete(recursive: true));
      final dbFile = File('${tmp.path}/a.sqlite');
      final backup = File('${tmp.path}/backup.sqlite');
      var a = await device(executor: NativeDatabase(dbFile));
      final b = await device();
      await connect([a, b]);
      await addAccount(a, 'before', 'Before backup');
      await syncAll([a, b]);

      await a.exec('VACUUM INTO ?', [backup.path]);

      await addAccount(a, 'after', 'After backup');
      await a.sync();
      await b.exec(
        "UPDATE accounts SET name = 'Edited on B', "
        "updated_at = '2031-01-01T00:00:00.000Z' WHERE id = 'before'",
      );
      await b.sync();

      // Restore: replace the database file, empty the queue, set the flag.
      await a.db.close();
      devices.remove(a);
      await backup.copy(dbFile.path);
      final restored = AppDatabase(NativeDatabase(dbFile));
      await restored.customStatement('DELETE FROM pending_sync_changes');
      a = a.withDatabase(restored);
      devices.add(a);
      final rebootstrap = SyncRebootstrap(a.prefs, a.outbox);
      await rebootstrap.markRequired();
      await rebootstrap.discardOutbox();
      expect(
        await a.count("SELECT COUNT(*) FROM accounts WHERE id='after'"),
        0,
      );

      await a.sync();
      expect(a.prefs.getBool(SyncRebootstrap.prefsKey), isNull);
      await syncAll([a, b]);
      await expectConverged([a, b]);
      expect(
        await a.count("SELECT COUNT(*) FROM accounts WHERE id='after'"),
        1,
      );
      expect(
        (await a.rows(
          "SELECT name FROM accounts WHERE id='before'",
        )).single['name'],
        'Edited on B',
      );
      // Sequences continue after the files uploaded before the restore.
      final aFiles = folder.syncFiles(device: a.deviceId);
      expect(aFiles.map((f) => f.name).toSet().length, aFiles.length);
    });
  });

  group('three devices', () {
    test('mixed offline edits converge to identical databases', () async {
      final a = await device();
      final b = await device();
      final c = await device();
      await connect([a, b, c]);
      await addAccount(a, 'shared', 'Shared');
      await syncAll([a, b, c]);
      final groceries = await a.t!.categoryId('Groceries');
      await a.t!.addTransaction(
        id: 'ta',
        accountId: 'shared',
        amount: -1,
        categoryId: groceries,
      );
      await b.t!.addTransaction(id: 'tb', accountId: 'shared', amount: -2);
      await c.exec(
        "UPDATE accounts SET name = 'C', updated_at = '2030-01-01T00:00:00.000Z' WHERE id = 'shared'",
      );
      await b.exec(
        "UPDATE accounts SET name = 'B', updated_at = '2030-01-02T00:00:00.000Z' WHERE id = 'shared'",
      );
      await a.exec("UPDATE categories SET name = 'Food' WHERE id = ?", [
        groceries,
      ]);
      await b.t!.budgeting.setCategoryBudgetedAmount(
        groceries,
        500,
        DateTime.utc(2025, 1),
      );
      await c.t!.budgeting.setCategoryBudgetedAmount(
        groceries,
        700,
        DateTime.utc(2025, 1),
      );
      await syncAll([c, b, a], rounds: 3);
      await expectConverged([a, b, c]);
      expect((await c.rows('SELECT name FROM accounts')).single['name'], 'B');
    });
  });

  test('every synced column of every synced table round-trips', () async {
    final a = await device();
    final b = await device();
    await connect([a, b]);
    final groceries = await a.t!.categoryId('Groceries');
    await addAccount(a, 'acc', 'Main');
    await a.exec(
      "UPDATE accounts SET color = 5, icon = 'bank', notes = 'n', "
      "is_closed = 1, starting_balance = 1234 WHERE id = 'acc'",
    );
    await a.exec(
      'UPDATE categories SET goal_type = ?, target_amount = 5000, '
      "target_date = '2025-12-31T00:00:00.000Z', color = 3, icon = 'cart', "
      'is_hidden = 1, sort_order = 9 WHERE id = ?',
      ['target', groceries],
    );
    await a.exec(
      'INSERT INTO payees (id, name, auto_category_id, default_account_id, '
      "icon, color, notes, is_favorite) VALUES ('p', 'Shop', ?, 'acc', "
      "'store', 7, 'pn', 1)",
      [groceries],
    );
    await a.exec(
      'INSERT INTO transactions (id, account_id, date, amount, payee_id, '
      'category_id, memo, cleared, approved, is_deleted) VALUES '
      "('t', 'acc', '2025-05-01T00:00:00.000Z', -1999, 'p', ?, 'memo', 2, 0, 1)",
      [groceries],
    );
    await a.exec(
      'INSERT INTO scheduled_transactions (id, account_id, payee_id, '
      'category_id, amount, frequency, interval, occurrence_count, next_date, '
      'end_date, auto_approve, memo, anchor_day) VALUES '
      "('s', 'acc', 'p', ?, -500, 'monthly', 2, 10, "
      "'2025-01-31T00:00:00.000Z', '2026-01-31T00:00:00.000Z', 1, 'gym', 31)",
      [groceries],
    );
    await a.exec(
      'INSERT INTO budget_templates (id, name, data, created_at) VALUES '
      "('bt', 'Base', '{\"x\":1}', '2025-01-01T00:00:00.000Z')",
    );
    await a.exec(
      'INSERT INTO import_profiles (id, name, date_format, decimal_separator, '
      'outflow_is_negative, date_column, amount_column, payee_column, '
      "memo_column, category_column, created_at) VALUES ('ip', 'Bank', "
      "'yyyy-MM-dd', ',', 1, 'd', 'a', 'p', 'm', 'c', "
      "'2025-01-01T00:00:00.000Z')",
    );
    await a.exec(
      'INSERT INTO rules (id, name, description, priority, is_active, '
      'match_logic, conditions, actions, created_at, updated_at) VALUES '
      "('r', 'Rule', 'desc', 3, 0, 'and', '[]', '[]', "
      "'2025-01-01T00:00:00.000Z', '2025-01-01T00:00:00.000Z')",
    );
    await a.exec(
      "INSERT INTO report_notes (id, date, note) VALUES ('rn', '2025-05', 'x')",
    );
    await a.t!.budgeting.setCategoryBudgetedAmount(
      groceries,
      4200,
      DateTime.utc(2025, 5),
    );
    await syncAll([a, b]);
    await expectConverged([a, b]);
    for (final table in AppDatabase.syncedTables) {
      expect(
        await b.count('SELECT COUNT(*) FROM "$table"'),
        greaterThan(0),
        reason: table,
      );
    }
  });
}
