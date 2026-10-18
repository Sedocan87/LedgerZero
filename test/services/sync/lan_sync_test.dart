import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/lan/lan_auth.dart';
import 'package:ledger_zero/services/sync/lan/lan_discovery.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/lan/lan_protocol.dart';
import 'package:ledger_zero/services/sync/lan/lan_sync_service.dart';
import 'package:ledger_zero/services/sync/lan/local_sync_folder.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/security_fakes.dart' show InMemorySecureStore;
import '../../helpers/sync_simulation.dart';
import '../../helpers/test_database.dart';

/// A simulated phone: real database and engine, Wi-Fi sync over loopback.
class _Phone {
  _Phone._(this.t, this.dir, this.service, this.engine, this.deviceId);

  final TestDatabase t;
  final Directory dir;
  final LanSyncService service;
  final SyncEngine engine;
  final String deviceId;
  int activity = 0;

  static Future<_Phone> create(String name) async {
    final dir = await Directory.systemTemp.createTemp('lz_lan_');
    final t = TestDatabase();
    final prefs = InMemoryPrefs();
    final deviceId = const Uuid().v4();
    final service = LanSyncService(
      folder: LocalSyncFolder(() async => Directory('${dir.path}/lan')),
      pairingStore: LanPairingStore(InMemorySecureStore()),
      peers: LanPeers(prefs),
      deviceId: deviceId,
      deviceName: name,
      serverPort: 0,
      discoveryPort: 0,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final engine = SyncEngine(
      db: t.db,
      transport: service.transport,
      deviceId: deviceId,
      outbox: SyncOutbox(() async => Directory('${dir.path}/outbox')),
      prefs: prefs,
      config: const SyncEngineConfig(kdfParams: fastKdf),
    );
    final phone = _Phone._(t, dir, service, engine, deviceId);
    service.onActivity = () => phone.activity++;
    return phone;
  }

  /// The pairing code with this phone's loopback address.
  Future<LanPairingCode> code() async => LanPairingCode(
    pairing: service.pairing!,
    deviceId: deviceId,
    deviceName: service.deviceName,
    endpoints: [LanEndpoint('127.0.0.1', service.port!)],
  );

  Future<List<String>> accountNames() async =>
      [for (final a in await t.accounts.getAllAccounts()) a.name]..sort();

  Future<void> close() async {
    await service.stop();
    await t.close();
    await dir.delete(recursive: true);
  }
}

void main() {
  late _Phone a;
  late _Phone b;

  setUp(() async {
    a = await _Phone.create('Pixel');
    b = await _Phone.create('Xiaomi');
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  /// A starts Wi-Fi sync; B scans A's code and joins.
  Future<void> pairBoth() async {
    final pairing = LanPairing.generate();
    await a.service.pair(pairing);
    await a.service.start();
    await a.engine.createSyncFolder(pairing.passphrase);

    final code = LanPairingCode.decode((await a.code()).encode());
    await b.service.pair(code.pairing);
    await b.service.start();
    await b.service.addPeerFromCode(code);
    await b.engine.joinSyncFolder(code.pairing.passphrase);
  }

  test('two paired phones sync both ways over the network', () async {
    await pairBoth();
    await a.t.addAccount(id: 'acc-a', name: 'Joint checking');
    await a.engine.sync();

    await b.engine.sync();
    expect(await b.accountNames(), ['Joint checking']);

    await b.t.addAccount(id: 'acc-b', name: 'Groceries card');
    await b.engine.sync();
    // B pushed its new file to A right away.
    expect(a.activity, greaterThan(0));

    await a.engine.sync();
    expect(await a.accountNames(), ['Groceries card', 'Joint checking']);
    // A learned B's address from B's request.
    expect(a.service.peers[b.deviceId]?.lastSeen, isNotNull);
    expect(a.service.peers[b.deviceId]?.lastSync, isNotNull);
  });

  test('data from before pairing reaches a new phone that joins', () async {
    await a.t.addAccount(id: 'acc-a', name: 'Joint checking');
    final pairing = LanPairing.generate();
    await a.service.pair(pairing);
    await a.service.start();
    await a.engine.createSyncFolder(pairing.passphrase);
    await a.engine.sync();

    final code = LanPairingCode.decode((await a.code()).encode());
    await b.service.pair(code.pairing);
    await b.service.start();
    await b.service.addPeerFromCode(code);
    await b.engine.joinSyncFolder(code.pairing.passphrase);
    await b.engine.sync();

    expect(await b.accountNames(), ['Joint checking']);
  });

  test(
    'data from before pairing reaches the phone whose code was scanned',
    () async {
      await a.t.addAccount(id: 'acc-a', name: 'Joint checking');
      final pairing = LanPairing.generate();
      await b.service.pair(pairing);
      await b.service.start();
      await b.engine.createSyncFolder(pairing.passphrase);
      await b.engine.sync();

      final code = LanPairingCode.decode((await b.code()).encode());
      await a.service.pair(code.pairing);
      await a.service.start();
      await a.service.addPeerFromCode(code);
      await a.engine.joinSyncFolder(code.pairing.passphrase);
      await a.engine.sync();
      await b.engine.sync();

      expect(await b.accountNames(), ['Joint checking']);
    },
  );

  test('a phone joins with only the code, before discovery found it', () async {
    final pairing = LanPairing.generate();
    await a.service.pair(pairing);
    await a.service.start();
    await a.engine.createSyncFolder(pairing.passphrase);

    final code = await a.code();
    await b.service.pair(code.pairing);
    await b.service.start();
    await b.service.addPeerFromCode(code);

    final folderFiles = await b.service.folder.list();
    expect(folderFiles.keys, contains(SyncFileName.manifest));
    expect(b.service.peers[a.deviceId]?.lastSync, isNotNull);
  });

  test(
    'deleted (compacted) files are deleted on the other phone too',
    () async {
      await pairBoth();
      await a.t.addAccount(id: 'acc-a', name: 'Joint checking');
      await a.engine.sync();
      await b.engine.sync();
      final aFiles = [
        for (final name in (await b.service.folder.list()).keys)
          if (SyncFileName.tryParse(name)?.deviceId == a.deviceId) name,
      ];
      expect(aFiles, isNotEmpty);

      // What the engine's compaction does on A.
      final transport = a.service.transport;
      for (final file in await transport.listFiles()) {
        if (aFiles.contains(file.name)) {
          await transport.delete(file);
        }
      }
      await b.engine.sync();

      final left = (await b.service.folder.list()).keys;
      expect(left.where(aFiles.contains), isEmpty);
      // Not copied back to A either.
      final onA = (await a.service.folder.list()).keys;
      expect(onA.where(aFiles.contains), isEmpty);
    },
  );

  test('a phone with another pair key is refused', () async {
    await pairBoth();
    final stranger = LanClient(
      auth: LanAuth(LanPairing.generate().pairKey),
      deviceId: const Uuid().v4(),
    );
    final endpoint = LanEndpoint('127.0.0.1', a.service.port!);
    await expectLater(
      stranger.download(endpoint, SyncFileName.manifest),
      throwsA(isA<HttpException>()),
    );
    final state = LanFolderState(
      deviceId: const Uuid().v4(),
      deviceName: 'x',
      port: null,
      files: const {},
      deleted: const {},
      manifestHash: null,
    );
    await expectLater(
      stranger.exchange(endpoint, state),
      throwsA(isA<HttpException>()),
    );
  });

  test('phones paired with different codes do not mix their folders', () async {
    final first = LanPairing.generate();
    await a.service.pair(first);
    await a.service.start();
    await a.engine.createSyncFolder(first.passphrase);

    // B uses A's pair key but created its own sync folder.
    await b.service.pair(
      LanPairing(
        pairKey: first.pairKey,
        passphrase: LanPairing.generate().passphrase,
      ),
    );
    await b.service.start();
    await b.engine.createSyncFolder(b.service.pairing!.passphrase);
    await b.service.peers.upsert(
      LanPeer(
        deviceId: a.deviceId,
        name: 'Pixel',
        host: '127.0.0.1',
        port: a.service.port,
      ),
    );

    await expectLater(
      b.engine.sync(),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('different sync folders'),
        ),
      ),
    );
  });

  group('pairing code', () {
    test('round-trips and ignores whitespace', () {
      final pairing = LanPairing.generate();
      final code = LanPairingCode(
        pairing: pairing,
        deviceId: 'device-1',
        deviceName: 'Pixel 8',
        endpoints: const [LanEndpoint('192.168.1.20', 47321)],
      ).encode();
      final spaced = '${code.substring(0, 20)} \n${code.substring(20)}';
      final decoded = LanPairingCode.decode(spaced);
      expect(decoded.pairing.pairKey, pairing.pairKey);
      expect(decoded.pairing.passphrase, pairing.passphrase);
      expect(decoded.deviceName, 'Pixel 8');
      expect(decoded.endpoints.single.toString(), '192.168.1.20:47321');
    });

    test('rejects other text', () {
      expect(
        () => LanPairingCode.decode('https://example.com'),
        throwsFormatException,
      );
      expect(
        () => LanPairingCode.decode('lzpair1:not-base64!'),
        throwsFormatException,
      );
    });

    test('generated passphrases are long and random', () {
      final p1 = LanPairing.generate().passphrase;
      final p2 = LanPairing.generate().passphrase;
      expect(p1.length, 26);
      expect(p1, isNot(p2));
    });
  });

  group('request signing', () {
    final key = Uint8List.fromList(List.filled(32, 7));

    test('a valid request passes once; a replay or changed body fails', () {
      final client = LanAuth(key);
      final server = LanAuth(key);
      final body = utf8.encode('{"x":1}');
      final signed = client.sign(
        method: 'POST',
        path: '/v1/exchange',
        deviceId: 'dev',
        body: body,
      );
      expect(
        server
            .verify(
              value: signed.value,
              method: 'POST',
              path: '/v1/exchange',
              body: body,
            )
            ?.deviceId,
        'dev',
      );
      expect(
        server.verify(
          value: signed.value,
          method: 'POST',
          path: '/v1/exchange',
          body: body,
        ),
        isNull,
        reason: 'replay',
      );
      final again = client.sign(
        method: 'POST',
        path: '/v1/exchange',
        deviceId: 'dev',
        body: body,
      );
      expect(
        server.verify(
          value: again.value,
          method: 'POST',
          path: '/v1/exchange',
          body: utf8.encode('{"x":2}'),
        ),
        isNull,
      );
    });

    test('an old request is refused', () {
      final past = LanAuth(
        key,
        clock: () => DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final signed = past.sign(
        method: 'GET',
        path: '/v1/files/x',
        deviceId: 'dev',
        body: const [],
      );
      expect(
        LanAuth(key).verify(
          value: signed.value,
          method: 'GET',
          path: '/v1/files/x',
          body: const [],
        ),
        isNull,
      );
    });
  });

  group('clock skew', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));

    test('a request signed under the pair key with a wrong clock is told '
        'apart from a forged one', () {
      final skewed = LanAuth(
        key,
        clock: () => DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final signed = skewed.sign(
        method: 'GET',
        path: '/v1/files/x',
        deviceId: 'dev',
        body: const [],
      );
      final check = LanAuth(key).check(
        value: signed.value,
        method: 'GET',
        path: '/v1/files/x',
        body: const [],
      );
      expect(check, isA<LanAuthSkewed>());
      expect((check as LanAuthSkewed).skew.inMinutes, 5);
      expect(
        LanAuth(Uint8List(32)).check(
          value: signed.value,
          method: 'GET',
          path: '/v1/files/x',
          body: const [],
        ),
        isA<LanAuthRejected>(),
      );
    });

    test('the client learns the other phone\'s clock difference', () async {
      final dir = await Directory.systemTemp.createTemp('lz_skew_');
      addTearDown(() => dir.delete(recursive: true));
      final server = LanServer(
        folder: LocalSyncFolder(() async => Directory('${dir.path}/lan')),
        auth: LanAuth(
          key,
          clock: () => DateTime.now().add(const Duration(minutes: 7)),
        ),
        deviceId: '00000000-0000-4000-8000-000000000001',
        deviceName: () => 'Fast clock',
        peers: LanPeers(InMemoryPrefs()),
        preferredPort: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await server.start();
      addTearDown(server.stop);
      final client = LanClient(
        auth: LanAuth(key),
        deviceId: '00000000-0000-4000-8000-000000000002',
      );
      const mine = LanFolderState(
        deviceId: '00000000-0000-4000-8000-000000000002',
        deviceName: 'Me',
        port: null,
        files: {},
        deleted: {},
        manifestHash: null,
      );
      await expectLater(
        client.exchange(LanEndpoint('127.0.0.1', server.port!), mine),
        throwsA(
          isA<LanClockSkewException>().having(
            (e) => e.skew.inMinutes,
            'skew',
            7,
          ),
        ),
      );
    });

    test('the exchange response carries the peer\'s time', () async {
      await pairBoth();
      await b.engine.sync();
      expect(b.service.peerClockSkew, isNotNull);
      expect(
        b.service.peerClockSkew!.abs(),
        lessThan(const Duration(minutes: 1)),
      );
    });
  });

  test('discovery accepts beacons of paired phones only', () async {
    final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    probe.close();

    final key = LanPairing.generate().pairKey;
    final peers = LanPeers(InMemoryPrefs());
    final seen = <LanPeer>[];
    final discovery = LanDiscovery(
      auth: LanAuth(key),
      deviceId: 'me',
      deviceName: () => 'Me',
      serverPort: () => 1,
      peers: peers,
      onPeerSeen: seen.add,
      port: port,
      interval: const Duration(hours: 1),
      broadcastAddress: InternetAddress('127.0.0.255'),
    );
    await discovery.start();
    addTearDown(discovery.stop);

    final sender = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(sender.close);
    void beacon(Uint8List withKey, String device) {
      final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      sender.send(
        utf8.encode(
          jsonEncode({
            'v': 1,
            'd': device,
            'n': 'Other',
            'p': 47321,
            'm': minute,
            't': LanAuth(withKey).beaconTag(device, 47321, minute),
          }),
        ),
        InternetAddress.loopbackIPv4,
        port,
      );
    }

    beacon(LanPairing.generate().pairKey, 'stranger');
    beacon(key, 'partner');
    for (var i = 0; i < 50 && seen.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(seen.map((p) => p.deviceId), ['partner']);
    expect(peers['partner']!.host, '127.0.0.1');
    expect(peers['partner']!.port, 47321);
    expect(peers['stranger'], isNull);
  });
}
