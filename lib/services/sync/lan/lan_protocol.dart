import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/lan/lan_auth.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/lan/local_sync_folder.dart';

/// What one phone tells the other at the start of an exchange.
class LanFolderState {
  const LanFolderState({
    required this.deviceId,
    required this.deviceName,
    required this.port,
    required this.files,
    required this.deleted,
    required this.manifestHash,
    this.time,
  });

  final String deviceId;
  final String deviceName;

  /// The sender's clock when it answered (UTC), so the other phone can
  /// log and show the skew between the clocks.
  final DateTime? time;

  /// Where its own server listens (null: not listening).
  final int? port;

  /// Every sync file in its folder.
  final Set<String> files;

  /// Its own files it deleted (compaction); the other side deletes them too.
  final Set<String> deleted;

  /// SHA-256 of its manifest, null without one.
  final String? manifestHash;

  Map<String, Object?> toJson() => {
    'd': deviceId,
    'n': deviceName,
    'p': port,
    'f': files.toList(),
    'x': deleted.toList(),
    'm': manifestHash,
    't': time?.toUtc().toIso8601String(),
  };

  factory LanFolderState.fromJson(Map<String, Object?> json) => LanFolderState(
    deviceId: json['d'] as String,
    deviceName: json['n'] as String? ?? '',
    port: json['p'] as int?,
    files: {
      for (final f in json['f'] as List)
        if (f is String && LocalSyncFolder.isSyncFileName(f)) f,
    },
    deleted: {
      for (final f in json['x'] as List? ?? const [])
        if (f is String && LocalSyncFolder.isSyncFileName(f)) f,
    },
    manifestHash: json['m'] as String?,
    time: DateTime.tryParse(json['t'] as String? ?? '')?.toUtc(),
  );

  static Future<LanFolderState> of(
    LocalSyncFolder folder, {
    required String deviceId,
    required String deviceName,
    required int? port,
  }) async {
    final files = (await folder.list()).keys.toSet();
    final manifest = files.contains(SyncFileName.manifest)
        ? await folder.read(SyncFileName.manifest)
        : null;
    return LanFolderState(
      deviceId: deviceId,
      deviceName: deviceName,
      port: port,
      files: files,
      deleted: {
        for (final name in await folder.deleted())
          if (_ownedBy(name, deviceId)) name,
      },
      manifestHash: manifest == null
          ? null
          : sha256.convert(manifest).toString(),
      time: DateTime.now().toUtc(),
    );
  }
}

/// The other phone's clock differs from this one's by more than
/// `LanAuth.maxSkew`: its server refused the request (or this one would).
class LanClockSkewException implements Exception {
  const LanClockSkewException(this.skew);

  /// Other phone's time minus this phone's time.
  final Duration skew;

  @override
  String toString() => 'LanClockSkewException: ${skew.inMinutes} min';
}

bool _ownedBy(String name, String deviceId) =>
    SyncFileName.tryParse(name)?.deviceId == deviceId;

/// Applies the other phone's deletions of its own files to [folder].
Future<void> _applyDeletions(
  LocalSyncFolder folder,
  LanFolderState other,
) async {
  for (final name in other.deleted) {
    if (_ownedBy(name, other.deviceId)) {
      await folder.delete(name);
    }
  }
}

/// The phones were paired with different sync folders (different
/// manifests); their files cannot be read by each other.
class LanManifestMismatchException implements Exception {
  const LanManifestMismatchException();
  @override
  String toString() => 'LanManifestMismatchException';
}

/// Serves this phone's sync folder to the paired phones.
///
/// * `POST /v1/exchange`: folder states both ways (and the caller's
///   deletions are applied);
/// * `GET /v1/files/<name>`: one file;
/// * `PUT /v1/files/<name>`: stores one file (an existing file of the same
///   size is kept).
///
/// Every request must carry a valid [LanAuth] signature; anything else gets
/// 401 without a body. Bodies are limited to [maxBody] bytes. Only sync
/// file names are served or accepted.
class LanServer {
  LanServer({
    required this.folder,
    required this.auth,
    required this.deviceId,
    required this.deviceName,
    required this.peers,
    this.onReceived,
    this.preferredPort = defaultPort,
    this.bindAddress,
  });

  final LocalSyncFolder folder;
  final LanAuth auth;
  final String deviceId;
  final String Function() deviceName;
  final LanPeers peers;

  /// A paired phone stored new files here (the engine should apply them).
  final void Function()? onReceived;
  final int preferredPort;

  /// Defaults to every IPv4 interface; tests bind to loopback.
  final InternetAddress? bindAddress;

  static const int defaultPort = 47321;
  static const int maxBody = 64 * 1024 * 1024;

  /// On a 401 for clock skew: the server's time, seconds since the epoch.
  static const String timeHeader = 'x-lz-time';

  HttpServer? _server;

  int? get port => _server?.port;

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    final address = bindAddress ?? InternetAddress.anyIPv4;
    try {
      _server = await HttpServer.bind(address, preferredPort);
    } on SocketException {
      // Port taken (another app): any free port; discovery announces it.
      _server = await HttpServer.bind(address, 0);
    }
    _server!.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object e) => Logger.warning('Wi-Fi sync server: $e'),
    );
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final body = await _readBody(request);
      if (body == null) {
        response.statusCode = HttpStatus.requestEntityTooLarge;
        await response.close();
        return;
      }
      final path = request.uri.path;
      final check = auth.check(
        value: request.headers.value(LanAuth.header),
        method: request.method,
        path: path,
        body: body,
      );
      if (check is LanAuthSkewed && check.deviceId != deviceId) {
        // A paired phone with a wrong clock: tell it the time here, signed,
        // so it can show the user what to fix.
        response.statusCode = HttpStatus.unauthorized;
        response.headers.set(timeHeader, '${auth.nowSeconds}');
        response.headers.set(
          LanAuth.responseHeader,
          auth.signResponse(
            status: HttpStatus.unauthorized,
            nonce: check.nonce,
            body: const [],
          ),
        );
        await response.close();
        return;
      }
      if (check is! LanAuthOk || check.deviceId == deviceId) {
        response.statusCode = HttpStatus.unauthorized;
        await response.close();
        return;
      }
      final caller = check;
      final (status, out) = await _route(request, path, body, caller.deviceId);
      response.statusCode = status;
      response.headers.set(
        LanAuth.responseHeader,
        auth.signResponse(status: status, nonce: caller.nonce, body: out),
      );
      response.contentLength = out.length;
      response.add(out);
      await response.close();
    } catch (e) {
      Logger.warning('Wi-Fi sync request failed: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {
        // Connection already gone.
      }
    }
  }

  Future<(int, List<int>)> _route(
    HttpRequest request,
    String path,
    Uint8List body,
    String caller,
  ) async {
    if (request.method == 'POST' && path == '/v1/exchange') {
      final other = LanFolderState.fromJson(
        jsonDecode(utf8.decode(body)) as Map<String, Object?>,
      );
      if (other.deviceId != caller) {
        return (HttpStatus.badRequest, const <int>[]);
      }
      await _applyDeletions(folder, other);
      // The caller copies files both ways right after this: that counts
      // as a sync with it on this side too.
      final now = DateTime.now();
      await peers.upsert(
        LanPeer(
          deviceId: caller,
          name: other.deviceName,
          host: request.connectionInfo?.remoteAddress.address,
          port: other.port,
          lastSeen: now,
          lastSync: now,
        ),
      );
      final mine = await LanFolderState.of(
        folder,
        deviceId: deviceId,
        deviceName: deviceName(),
        port: port,
      );
      return (HttpStatus.ok, utf8.encode(jsonEncode(mine.toJson())));
    }
    if (path.startsWith('/v1/files/')) {
      final name = Uri.decodeComponent(path.substring('/v1/files/'.length));
      if (!LocalSyncFolder.isSyncFileName(name)) {
        return (HttpStatus.notFound, const <int>[]);
      }
      if (request.method == 'GET') {
        final bytes = await folder.read(name);
        return bytes == null
            ? (HttpStatus.notFound, const <int>[])
            : (HttpStatus.ok, bytes);
      }
      if (request.method == 'PUT') {
        final existing = await folder.list();
        if (existing[name] != body.length) {
          await folder.write(name, body);
          onReceived?.call();
        }
        return (HttpStatus.noContent, const <int>[]);
      }
    }
    return (HttpStatus.notFound, const <int>[]);
  }

  static Future<Uint8List?> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBody) {
        return null;
      }
    }
    return builder.takeBytes();
  }
}

/// Talks to a paired phone's [LanServer].
class LanClient {
  LanClient({required this.auth, required this.deviceId});

  final LanAuth auth;
  final String deviceId;

  static const Duration connectTimeout = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 60);

  Future<LanFolderState> exchange(LanEndpoint to, LanFolderState mine) async {
    final (status, body) = await _send(
      to,
      'POST',
      '/v1/exchange',
      utf8.encode(jsonEncode(mine.toJson())),
    );
    if (status != HttpStatus.ok) {
      throw HttpException('exchange: $status');
    }
    return LanFolderState.fromJson(
      jsonDecode(utf8.decode(body)) as Map<String, Object?>,
    );
  }

  Future<Uint8List?> download(LanEndpoint from, String name) async {
    final (status, body) = await _send(
      from,
      'GET',
      '/v1/files/${Uri.encodeComponent(name)}',
      const [],
    );
    if (status == HttpStatus.notFound) {
      return null;
    }
    if (status != HttpStatus.ok) {
      throw HttpException('download: $status');
    }
    return body;
  }

  Future<void> upload(LanEndpoint to, String name, Uint8List bytes) async {
    final (status, _) = await _send(
      to,
      'PUT',
      '/v1/files/${Uri.encodeComponent(name)}',
      bytes,
    );
    if (status != HttpStatus.noContent) {
      throw HttpException('upload: $status');
    }
  }

  Future<(int, Uint8List)> _send(
    LanEndpoint to,
    String method,
    String path,
    List<int> body,
  ) async {
    final client = HttpClient()..connectionTimeout = connectTimeout;
    try {
      final signed = auth.sign(
        method: method,
        path: path,
        deviceId: deviceId,
        body: body,
      );
      final request = await client
          .openUrl(
            method,
            Uri(scheme: 'http', host: to.host, port: to.port, path: path),
          )
          .timeout(requestTimeout);
      request.headers.set(LanAuth.header, signed.value);
      request.contentLength = body.length;
      request.add(body);
      final response = await request.close().timeout(requestTimeout);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(requestTimeout)) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (!auth.verifyResponse(
        value: response.headers.value(LanAuth.responseHeader),
        status: response.statusCode,
        nonce: signed.nonce,
        body: bytes,
      )) {
        throw const HttpException('response not authentic');
      }
      final theirTime = int.tryParse(
        response.headers.value(LanServer.timeHeader) ?? '',
      );
      if (response.statusCode == HttpStatus.unauthorized && theirTime != null) {
        throw LanClockSkewException(
          Duration(seconds: theirTime - auth.nowSeconds),
        );
      }
      return (response.statusCode, bytes);
    } finally {
      client.close(force: true);
    }
  }
}

/// Copies files between this phone's folder and the paired phones'.
class LanReplicator {
  LanReplicator({
    required this.folder,
    required this.client,
    required this.peers,
    required this.deviceId,
    required this.deviceName,
    required this.localPort,
  });

  final LocalSyncFolder folder;
  final LanClient client;
  final LanPeers peers;
  final String deviceId;
  final String Function() deviceName;
  final int? Function() localPort;

  /// The last measured difference between a paired phone's clock and this
  /// one's (theirs minus ours), from the exchange response.
  Duration? lastPeerSkew;

  /// Exchanges files with every paired phone that has an address. Returns
  /// how many could be reached. Unreachable phones are skipped silently.
  Future<int> syncWithPeers() async {
    var reached = 0;
    for (final peer in peers.all) {
      if (peer.hasAddress && await syncWith(peer)) {
        reached++;
      }
    }
    return reached;
  }

  /// One exchange with [peer]: both deletions lists are applied, then this
  /// phone downloads what it lacks and uploads what the peer lacks.
  Future<bool> syncWith(LanPeer peer) async {
    final endpoint = LanEndpoint(peer.host!, peer.port!);
    try {
      final mine = await _state();
      final theirs = await client.exchange(endpoint, mine);
      final theirTime = theirs.time;
      if (theirTime != null) {
        final skew = theirTime.difference(DateTime.now().toUtc());
        lastPeerSkew = skew;
        if (skew.abs() > const Duration(minutes: 1)) {
          Logger.warning(
            'Wi-Fi sync: ${peer.name} clock differs by ${skew.inSeconds} s',
          );
        }
      }
      if (mine.manifestHash != null &&
          theirs.manifestHash != null &&
          mine.manifestHash != theirs.manifestHash) {
        throw const LanManifestMismatchException();
      }
      await _applyDeletions(folder, theirs);
      final local = (await folder.list()).keys.toSet();
      for (final name in theirs.files.difference(local)) {
        if (mine.deleted.contains(name) || theirs.deleted.contains(name)) {
          continue;
        }
        final bytes = await client.download(endpoint, name);
        if (bytes != null) {
          await folder.write(name, bytes);
        }
      }
      for (final name in local.difference(theirs.files)) {
        if (theirs.deleted.contains(name)) {
          continue;
        }
        final bytes = await folder.read(name);
        if (bytes != null) {
          await client.upload(endpoint, name, bytes);
        }
      }
      await peers.upsert(
        peer.copyWith(
          name: theirs.deviceName,
          port: theirs.port,
          lastSeen: DateTime.now(),
          lastSync: DateTime.now(),
        ),
      );
      return true;
    } on LanManifestMismatchException {
      rethrow;
    } on LanClockSkewException catch (e) {
      lastPeerSkew = e.skew;
      rethrow;
    } catch (e) {
      Logger.info('Wi-Fi sync: ${peer.name} not reachable ($e)');
      return false;
    }
  }

  /// Sends a new file to the phones reached recently (best effort; the next
  /// exchange copies anything missed).
  Future<void> push(String name, Uint8List bytes) async {
    final recent = DateTime.now().subtract(const Duration(minutes: 10));
    for (final peer in peers.all) {
      final synced = peer.lastSync;
      if (!peer.hasAddress || synced == null || synced.isBefore(recent)) {
        continue;
      }
      try {
        await client.upload(LanEndpoint(peer.host!, peer.port!), name, bytes);
      } catch (e) {
        Logger.info('Wi-Fi sync: push to ${peer.name} failed ($e)');
      }
    }
  }

  Future<LanFolderState> _state() => LanFolderState.of(
    folder,
    deviceId: deviceId,
    deviceName: deviceName(),
    port: localPort(),
  );
}
