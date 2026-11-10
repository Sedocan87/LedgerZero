// What happens to captured changes while nothing syncs (provider "None",
// Turn off Wi-Fi sync): two real databases and engines over a fake folder,
// with the real controller driving phone A (Wi-Fi sync set up; the engine
// runs against the fake folder).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_sync_service.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';

import '../../helpers/lan_test_service.dart';
import '../../helpers/sync_simulation.dart';

const passphrase = 'correct horse battery staple';

class _Online implements ConnectivityService {
  @override
  Stream<ConnectionStatus> get connectionStatusStream => const Stream.empty();
  @override
  Future<bool> get isConnected async => true;
  @override
  Future<bool> get isWifi async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeSyncFolder folder;
  late SimDevice a;
  late SimDevice b;
  late LanSyncService lan;

  /// The controller of phone [a] (manual frequency: only `syncNow` runs).
  SyncController controllerOf(SimDevice device, {String? provider}) {
    if (provider != null) {
      device.prefs.values['sync_provider'] = provider;
    }
    device.prefs.values['sync_frequency'] = SyncFrequency.manual.name;
    final c = SyncController(
      prefs: device.prefs,
      connectivity: _Online(),
      dependencies: () => SyncDependencies(
        engineFor: (_) => device.engine,
        dao: device.db.syncDao,
        resolver: SyncConflictResolver(device.db),
      ),
      transportFor: (p) =>
          p == SyncProviderType.localWifi ? device.transport : null,
      lan: lan,
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The app is closed and opened again.
  Future<void> restart(SyncController c) async {
    await c.onLockStateChanged(AppLockState.locked);
    await c.onLockStateChanged(AppLockState.unlocked);
  }

  Future<int> pending(SimDevice d) =>
      d.count('SELECT COUNT(*) FROM pending_sync_changes');

  setUp(() async {
    folder = FakeSyncFolder();
    a = await SimDevice.create(folder);
    b = await SimDevice.create(folder);
    lan = await testLanSync(a.prefs);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  group('a phone that syncs', () {
    late SyncController c;

    setUp(() async {
      await a.engine.createSyncFolder(passphrase);
      await b.engine.joinSyncFolder(passphrase);
      await a.t!.addAccount(id: 'chk', name: 'Checking');
      await a.exec("INSERT INTO payees (id, name) VALUES ('p', 'Bakery')");
      await syncAll([a, b]);
      c = controllerOf(a, provider: 'localWifi');
      await c.onLockStateChanged(AppLockState.unlocked);
    });

    test('provider "None" and back: changes made in between still reach '
        'the partner', () async {
      await c.setProvider(SyncProviderType.none);
      await a.t!.addTransaction(id: 't1', accountId: 'chk', amount: -500);
      await restart(c);

      await c.setProvider(SyncProviderType.localWifi);
      await c.syncNow();
      await b.sync();

      expect(c.state.setup, SyncSetupState.ready);
      expect(await b.count('SELECT COUNT(*) FROM transactions'), 1);
    });

    test('Turn off Wi-Fi sync and pair again: deletes made in between '
        'reach the partner', () async {
      await c.disconnect();
      expect(c.state.selectedProvider, SyncProviderType.none);
      expect(lan.isPaired, isFalse);
      await restart(c);
      await a.exec("DELETE FROM payees WHERE id = 'p'");
      await restart(c);

      // Pairing again (the QR code) stores a new pairing; the folder asks
      // for the passphrase like any device that joins.
      await lan.pair(LanPairing.generate());
      await c.setProvider(SyncProviderType.localWifi);
      await c.syncNow();
      expect(c.state.setup, SyncSetupState.needsPassphrase);
      expect(await c.enterPassphrase(passphrase), SyncPassphraseResult.ok);
      await c.syncNow();
      await b.sync();

      expect(await b.count('SELECT COUNT(*) FROM payees'), 0);
    });

    test('without a provider the captured changes are squashed to one '
        'entry per row, not dropped', () async {
      await c.setProvider(SyncProviderType.none);
      for (final name in ['One', 'Two', 'Three']) {
        await a.exec("UPDATE payees SET name = '$name' WHERE id = 'p'");
      }
      await a.exec("INSERT INTO payees (id, name) VALUES ('q', 'Kiosk')");
      await a.exec("DELETE FROM payees WHERE id = 'q'");
      expect(await pending(a), greaterThanOrEqualTo(5));

      await restart(c);

      expect(
        await a.rows(
          'SELECT record_id, action FROM pending_sync_changes ORDER BY id',
        ),
        [
          {'record_id': 'p', 'action': 'UPDATE'},
          {'record_id': 'q', 'action': 'DELETE'},
        ],
      );
    });
  });

  test('a phone that never had a sync folder keeps no captured '
      'changes', () async {
    final c = controllerOf(a);
    await a.exec("INSERT INTO payees (id, name) VALUES ('p', 'Bakery')");
    expect(await pending(a), greaterThan(0));

    await c.onLockStateChanged(AppLockState.unlocked);

    expect(await pending(a), 0);
  });
}
