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

  test('an answered snapshot request is deleted on both phones and not '
      'answered again', () async {
    await pairBoth();
    await a.engine.sync();
    await b.engine.sync();
    await a.t.addAccount(id: 'acc-a', name: 'Joint checking');
    await a.engine.sync();

    // B's copy of A's file is damaged; the user taps "Skip file".
    final damaged = [
      for (final name in (await b.service.folder.list()).keys)
        if (SyncFileName.tryParse(name) case final n?)
          if (n.deviceId == a.deviceId && n.kind == SyncFileKind.changes) n,
    ].reduce((x, y) => x.sequence > y.sequence ? x : y).name;
    final bytes = (await b.service.folder.read(damaged))!;
    bytes[bytes.length - 3] ^= 0x01;
    await b.service.folder.write(damaged, bytes);
    await b.engine.sync();
    final quarantined = (await b.t.db.syncDao.getQuarantine()).single;
    await b.engine.skipQuarantined(quarantined.filename);
    await b.engine.sync(); // writes the request
    final request = SyncFileName.request(a.deviceId, b.deviceId);
    expect((await b.service.folder.list()).keys, contains(request));

    await a.engine.sync(); // answers with a snapshot
    await b.engine.sync(); // repaired
    expect(await b.accountNames(), ['Joint checking']);

    Future<int> snapshotsOfA() async => [
      for (final name in (await a.service.folder.list()).keys)
        if (SyncFileName.tryParse(name) case final n?)
          if (n.deviceId == a.deviceId && n.kind == SyncFileKind.snapshot) n,
    ].length;
    expect(await snapshotsOfA(), 1);

    // Later runs with new changes: the request does not come back, and A
    // writes no further snapshot.
    for (var i = 0; i < 3; i++) {
      await a.t.addAccount(id: 'more-$i', name: 'More $i');
      await a.engine.sync();
      await b.engine.sync();
    }
    expect((await a.service.folder.list()).keys, isNot(contains(request)));
    expect((await b.service.folder.list()).keys, isNot(contains(request)));
    expect(await snapshotsOfA(), 1);

    // A second request later on is a new one and is answered.
    await b.service.transport.upload(request, Uint8List.fromList([1]));
    await a.engine.sync();
    expect((await a.service.folder.list()).keys, isNot(contains(request)));
    await b.engine.sync();
    expect((await b.service.folder.list()).keys, isNot(contains(request)));
  });

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

    test('a pairing the KeyStore cannot read any more is forgotten, so '
        'Wi-Fi sync asks to pair again', () async {
      final secure = InMemorySecureStore();
      final store = LanPairingStore(secure);
      await store.write(LanPairing.generate());
      secure.readError = Exception('javax.crypto.AEADBadTagException');
      expect(await store.read(), isNull);
      expect(secure.values, isEmpty);
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

    test('a request that names its recipient is refused by any other '
        'phone', () {
      final client = LanAuth(key);
      final body = utf8.encode('{}');
      ({String value, String nonce}) signed() => client.sign(
        method: 'POST',
        path: '/v1/exchange',
        deviceId: 'dev',
        body: body,
        recipient: 'phone-b',
      );
      LanAuthCheck check(String value, String? self) => LanAuth(key).check(
        value: value,
        method: 'POST',
        path: '/v1/exchange',
        body: body,
        self: self,
      );

      expect(signed().value, startsWith('v2 '));
      expect(check(signed().value, 'phone-b'), isA<LanAuthOk>());
      // Replayed to a third paired phone (same pair key).
      expect(check(signed().value, 'phone-c'), isA<LanAuthRejected>());
      expect(check(signed().value, null), isA<LanAuthRejected>());
    });

    test('a request in the scheme of the previous app version is still '
        'accepted', () {
      final signed = LanAuth(key).sign(
        method: 'GET',
        path: '/v1/files/x',
        deviceId: 'dev',
        body: const [],
      );
      expect(signed.value, startsWith('v1 '));
      expect(
        LanAuth(key).check(
          value: signed.value,
          method: 'GET',
          path: '/v1/files/x',
          body: const [],
          self: 'phone-b',
        ),
        isA<LanAuthOk>(),
      );
    });

    test('phones switch to recipient-bound requests once each knows the '
        'other understands them', () async {
      await pairBoth();
      // From the pairing code alone B does not know what A understands.
      await b.engine.sync();
      expect(b.service.peers[a.deviceId]!.authVersion, 2);
      expect(a.service.peers[b.deviceId]!.authVersion, 2);
      // The following exchanges (now signed for the recipient) still work.
      await a.t.addAccount(id: 'acc-a', name: 'Joint checking');
      await a.engine.sync();
      await b.engine.sync();
      expect(await b.accountNames(), ['Joint checking']);
    });

    test('a folder state from the previous app version (no scheme field) '
        'means the old scheme', () {
      final state = LanFolderState.fromJson({
        'd': '00000000-0000-4000-8000-000000000001',
        'n': 'Old build',
        'p': 47321,
        'f': <String>[],
        'x': <String>[],
        'm': null,
        't': null,
      });
      expect(state.authVersion, 1);
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

  group('requests refused before their body is read', () {
    final key = Uint8List.fromList(List.filled(32, 9));
    const serverId = '00000000-0000-4000-8000-000000000001';
    const clientId = '00000000-0000-4000-8000-000000000002';
    late Directory dir;
    late LanServer server;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('lz_lan_dos_');
      server = LanServer(
        folder: LocalSyncFolder(() async => Directory('${dir.path}/lan')),
        auth: LanAuth(key),
        deviceId: serverId,
        deviceName: () => 'Server',
        peers: LanPeers(InMemoryPrefs()),
        preferredPort: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await server.start();
    });

    tearDown(() async {
      await server.stop();
      await dir.delete(recursive: true);
    });

    /// Sends only the head of a request that announces [contentLength]
    /// body bytes. Returns the socket and the status line of the answer
    /// (which completes only if the server answers without the body).
    Future<(Socket, Future<String>)> head({
      required String auth,
      required int contentLength,
    }) async {
      final socket = await Socket.connect('127.0.0.1', server.port!);
      final status = utf8.decoder
          .bind(socket)
          .join()
          .then((text) => text.split('\r\n').first);
      socket.write(
        'PUT /v1/files/x HTTP/1.1\r\n'
        'Host: phone\r\n'
        '${LanAuth.header}: $auth\r\n'
        'Content-Length: $contentLength\r\n\r\n',
      );
      await socket.flush();
      return (socket, status);
    }

    String authAt(DateTime time) =>
        'v1 $clientId ${time.millisecondsSinceEpoch ~/ 1000} nonce mac';

    Future<String> answer({
      required String auth,
      required int contentLength,
    }) async {
      final (socket, status) = await head(
        auth: auth,
        contentLength: contentLength,
      );
      addTearDown(socket.destroy);
      return status.timeout(const Duration(seconds: 5));
    }

    test('a malformed auth header', () async {
      expect(
        await answer(auth: 'hello', contentLength: 50 * 1024 * 1024),
        contains('401'),
      );
    });

    test('a body above the limit', () async {
      expect(
        await answer(
          auth: authAt(DateTime.now()),
          contentLength: LanServer.maxBody + 1,
        ),
        contains('413'),
      );
    });

    test('a large body with a timestamp outside the window', () async {
      expect(
        await answer(
          auth: authAt(DateTime.now().subtract(const Duration(minutes: 10))),
          contentLength: 50 * 1024 * 1024,
        ),
        contains('401'),
      );
    });

    test('more large bodies or connections at a time than allowed', () async {
      final held = <Socket>[];
      addTearDown(() {
        for (final socket in held) {
          socket.destroy();
        }
      });
      // Two uploads announced, none delivered: a third is turned away.
      for (var i = 0; i < LanServer.maxLargeBodies; i++) {
        held.add(
          (await head(
            auth: authAt(DateTime.now()),
            contentLength: 50 * 1024 * 1024,
          )).$1,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        await answer(
          auth: authAt(DateTime.now()),
          contentLength: 50 * 1024 * 1024,
        ),
        contains('503'),
      );
      // Small requests still get through until the connection limit.
      for (
        var i = LanServer.maxLargeBodies;
        i < LanServer.maxConnections;
        i++
      ) {
        held.add(
          (await head(auth: authAt(DateTime.now()), contentLength: 10)).$1,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        await answer(auth: authAt(DateTime.now()), contentLength: 10),
        contains('503'),
      );

      // Once they are gone the server answers again.
      for (final socket in held) {
        socket.destroy();
      }
      held.clear();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final client = LanClient(auth: LanAuth(key), deviceId: clientId);
      const mine = LanFolderState(
        deviceId: clientId,
        deviceName: 'Me',
        port: null,
        files: {},
        deleted: {},
        manifestHash: null,
      );
      final theirs = await client.exchange(
        LanEndpoint('127.0.0.1', server.port!),
        mine,
        recipient: serverId,
      );
      expect(theirs.deviceId, serverId);
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
