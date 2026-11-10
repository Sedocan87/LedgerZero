// Scenarios in which two phones used to end up with different data for
// good: deletes made while disconnected, rows moved into a personal
// account, foreign-key repairs, compacted files. Real databases and
// engines over a fake folder (test/helpers/sync_simulation.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';

import '../../helpers/sync_simulation.dart';

const passphrase = 'correct horse battery staple';

void main() {
  late FakeSyncFolder folder;
  final devices = <SimDevice>[];

  Future<SimDevice> device({
    SyncEngineConfig? config,
    DateTime Function()? clock,
  }) async {
    final d = await SimDevice.create(folder, config: config, clock: clock);
    devices.add(d);
    return d;
  }

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

  setUp(() {
    folder = FakeSyncFolder();
    devices.clear();
  });

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
  });

  group('reconnecting to the same folder', () {
    Future<(SimDevice, SimDevice)> pairWithPayeeAndCategory() async {
      final a = await device();
      final b = await device();
      await connect([a, b]);
      await a.exec("INSERT INTO payees (id, name) VALUES ('p', 'Bakery')");
      await a.exec(
        'INSERT INTO categories (id, name, is_hidden) '
        "VALUES ('c', 'Gym', 0)",
      );
      await syncAll([a, b]);
      expect(await b.count('SELECT COUNT(*) FROM payees'), 1);
      return (a, b);
    }

    test('deletes made while disconnected reach the partner', () async {
      final (a, b) = await pairWithPayeeAndCategory();

      await a.engine.forgetKey(); // Disconnect
      await a.exec("DELETE FROM payees WHERE id = 'p'");
      await a.exec("DELETE FROM categories WHERE id = 'c'");
      await a.engine.joinSyncFolder(passphrase);
      await syncAll([a, b]);

      expect(await b.count('SELECT COUNT(*) FROM payees'), 0);
      expect(await b.count("SELECT COUNT(*) FROM categories WHERE id='c'"), 0);
      await expectConverged([a, b]);
    });

    test('a delete whose capture was lost (older app version) is sent as a '
        'tombstone by the re-share', () async {
      final (a, b) = await pairWithPayeeAndCategory();

      await a.engine.forgetKey();
      await a.exec("DELETE FROM payees WHERE id = 'p'");
      await a.exec("DELETE FROM categories WHERE id = 'c'");
      // What the previous app version did on Disconnect and at every start
      // without a provider.
      await a.exec('DELETE FROM pending_sync_changes');
      await a.engine.joinSyncFolder(passphrase);
      await syncAll([a, b]);

      expect(await b.count('SELECT COUNT(*) FROM payees'), 0);
      expect(await b.count("SELECT COUNT(*) FROM categories WHERE id='c'"), 0);
      await expectConverged([a, b]);
    });

    test('an uncaptured delete does not destroy an edit the partner made '
        'since', () async {
      final (a, b) = await pairWithPayeeAndCategory();

      await a.engine.forgetKey();
      await a.exec("DELETE FROM payees WHERE id = 'p'");
      await a.exec('DELETE FROM pending_sync_changes');
      await b.exec("UPDATE payees SET name = 'Bakery Schmidt' WHERE id = 'p'");
      await b.sync();
      await a.engine.joinSyncFolder(passphrase);
      await syncAll([a, b]);

      // The time of the delete is unknown, so the later edit wins.
      expect(await a.rows('SELECT name FROM payees'), [
        {'name': 'Bakery Schmidt'},
      ]);
      await expectConverged([a, b]);
    });
  });

  group('a synced row moved into a personal account', () {
    late SimDevice a;
    late SimDevice b;

    setUp(() async {
      a = await device();
      b = await device();
      await connect([a, b]);
      await a.t!.addAccount(
        id: 'chk',
        name: 'Checking',
        startingBalance: 100000,
      );
      await a.t!.addAccount(
        id: 'mine',
        name: 'Pocket money',
        owner: AccountOwner.me,
      );
      await a.t!.addTransaction(id: 't1', accountId: 'chk', amount: -30000);
      await syncAll([a, b]);
      expect(await b.count('SELECT COUNT(*) FROM transactions'), 1);
    });

    Future<int> balance(SimDevice d, String id) async =>
        (await d.t!.accounts.getAccountById(id))!.balance;

    test('disappears from the partner, and the balances agree', () async {
      final t1 = (await a.t!.transactions.getTransactionById('t1'))!;
      await a.t!.transactions.updateTransaction(t1.copyWith(accountId: 'mine'));
      await syncAll([a, b]);

      expect(await b.count('SELECT COUNT(*) FROM transactions'), 0);
      expect(await balance(a, 'chk'), 100000);
      expect(await balance(b, 'chk'), 100000);
      expect(await balance(a, 'mine'), -30000);
      expect(await balance(b, 'mine'), -30000);
      // Still on the owner's phone, and not sent again.
      expect(await a.count('SELECT COUNT(*) FROM transactions'), 1);
      final files = folder.files.length;
      await syncAll([a, b]);
      expect(folder.files.length, files);
    });

    test('and back into the shared account returns to the partner', () async {
      final t1 = (await a.t!.transactions.getTransactionById('t1'))!;
      await a.t!.transactions.updateTransaction(t1.copyWith(accountId: 'mine'));
      await syncAll([a, b]);
      final moved = (await a.t!.transactions.getTransactionById('t1'))!;
      await a.t!.transactions.updateTransaction(
        moved.copyWith(accountId: 'chk'),
      );
      await syncAll([a, b]);

      expect(
        await b.rows('SELECT id, account_id, is_deleted FROM transactions'),
        [
          {'id': 't1', 'account_id': 'chk', 'is_deleted': 0},
        ],
      );
      expect(await balance(b, 'chk'), 70000);
      expect(await balance(b, 'mine'), 0);
    });

    test('a schedule moved into a personal account disappears from the '
        'partner', () async {
      await a.exec(
        'INSERT INTO scheduled_transactions (id, account_id, amount, '
        "auto_approve) VALUES ('s1', 'chk', -500, 0)",
      );
      await syncAll([a, b]);
      expect(await b.count('SELECT COUNT(*) FROM scheduled_transactions'), 1);

      await a.exec(
        "UPDATE scheduled_transactions SET account_id = 'mine' "
        "WHERE id = 's1'",
      );
      await syncAll([a, b]);

      expect(await b.count('SELECT COUNT(*) FROM scheduled_transactions'), 0);
      expect(await a.count('SELECT COUNT(*) FROM scheduled_transactions'), 1);
    });
  });
}
