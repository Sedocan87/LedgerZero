import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/lan/lan_sync_service.dart';
import 'package:ledger_zero/services/sync/lan/local_sync_folder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_fakes.dart' show InMemorySecureStore;

/// A Wi-Fi sync service for controller tests whose engine is fake: it
/// never starts its server or discovery (no sockets, so it also works in
/// widget tests), and its folder is a temporary path that is only created
/// if something writes to it. [paired] stores a fresh pairing, so the
/// controller treats Wi-Fi sync as set up.
Future<LanSyncService> testLanSync(
  SharedPreferences prefs, {
  bool paired = true,
  String deviceId = '00000000-0000-4000-8000-000000000001',
}) async {
  final dir = Directory(
    '${Directory.systemTemp.path}/lz_lan_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  final lan = _QuietLanSyncService(
    folder: LocalSyncFolder(() async => dir),
    pairingStore: LanPairingStore(InMemorySecureStore()),
    peers: LanPeers(prefs),
    deviceId: deviceId,
    deviceName: 'Test phone',
  );
  addTearDown(() async {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  if (paired) {
    await lan.pair(LanPairing.generate());
  }
  return lan;
}

class _QuietLanSyncService extends LanSyncService {
  _QuietLanSyncService({
    required super.folder,
    required super.pairingStore,
    required super.peers,
    required super.deviceId,
    required super.deviceName,
  });

  @override
  Future<void> start() async {}
}

/// Records an exchange with a paired phone at [time] (what "last sync"
/// shows with Wi-Fi sync).
Future<void> recordPeerExchange(LanSyncService lan, DateTime time) =>
    lan.peers.upsert(
      LanPeer(
        deviceId: '00000000-0000-4000-8000-000000000002',
        name: 'Other phone',
        lastSync: time,
      ),
    );
