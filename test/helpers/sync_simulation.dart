import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show QueryExecutor, driftRuntimeOptions;
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'test_database.dart';

/// Cheap KDF parameters for tests (the format stores them in the manifest).
KdfParams fastKdf() => KdfParams.argon2id(memoryKiB: 8, iterations: 1);

/// SharedPreferences held in memory, one instance per simulated device.
class InMemoryPrefs implements SharedPreferences {
  final Map<String, Object> values = {};

  @override
  bool? getBool(String key) => values[key] as bool?;
  @override
  String? getString(String key) => values[key] as String?;
  @override
  int? getInt(String key) => values[key] as int?;
  @override
  bool containsKey(String key) => values.containsKey(key);
  @override
  Object? get(String key) => values[key];
  @override
  Future<bool> setBool(String key, bool value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StoredFile {
  final String id;
  final String name;
  Uint8List bytes;
  DateTime modified;

  StoredFile(this.id, this.name, this.bytes, this.modified);
}

/// The shared cloud folder: files by id (names may repeat, like on Drive).
class FakeSyncFolder {
  final Map<String, StoredFile> files = {};
  var _nextId = 0;
  var _tick = 0;

  /// Names that are not listed yet (eventual consistency / delay).
  final Set<String> hidden = {};

  StoredFile add(String name, Uint8List bytes) {
    final id = 'f${_nextId++}';
    final file = StoredFile(
      id,
      name,
      Uint8List.fromList(bytes),
      DateTime.utc(2030).add(Duration(seconds: _tick++)),
    );
    files[id] = file;
    return file;
  }

  List<StoredFile> named(String name) =>
      files.values.where((f) => f.name == name).toList();

  StoredFile single(String name) => named(name).single;

  List<String> get names => files.values.map((f) => f.name).toList()..sort();

  List<SyncFileName> syncFiles({String? device, SyncFileKind? kind}) {
    return [
      for (final f in files.values)
        if (SyncFileName.tryParse(f.name) case final n?)
          if ((device == null || n.deviceId == device) &&
              (kind == null || n.kind == kind))
            n,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }
}

/// In-memory transport over a [FakeSyncFolder]. Lists in pages of
/// [pageSize] (like Drive), can shuffle the listing order.
class FakeSyncTransport implements SyncTransport {
  final FakeSyncFolder folder;
  final int pageSize;
  final Random? shuffle;
  int listCalls = 0;
  int pageCalls = 0;
  int uploads = 0;
  int downloads = 0;

  FakeSyncTransport(this.folder, {this.pageSize = 100, this.shuffle});

  @override
  String get name => 'fake';

  @override
  Future<List<RemoteFile>> listFiles() async {
    listCalls++;
    final visible =
        folder.files.values
            .where((f) => !folder.hidden.contains(f.name))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final result = <RemoteFile>[];
    for (var i = 0; i < visible.length; i += pageSize) {
      pageCalls++;
      for (final f in visible.skip(i).take(pageSize)) {
        result.add(
          RemoteFile(
            f.name,
            f.id,
            size: f.bytes.length,
            modifiedTime: f.modified,
          ),
        );
      }
    }
    if (shuffle != null) {
      result.shuffle(shuffle);
    }
    return result;
  }

  @override
  Future<Uint8List> download(RemoteFile file) async {
    downloads++;
    final stored = folder.files[file.id];
    if (stored == null) {
      throw const FileSystemException('gone');
    }
    return Uint8List.fromList(stored.bytes);
  }

  @override
  Future<void> upload(String name, Uint8List bytes) async {
    uploads++;
    final existing = folder.named(name);
    if (existing.isNotEmpty) {
      if (existing.first.bytes.length == bytes.length ||
          name == SyncFileName.manifest) {
        return;
      }
      existing.first.bytes = Uint8List.fromList(bytes);
      return;
    }
    folder.add(name, bytes);
  }

  @override
  Future<void> delete(RemoteFile file) async {
    folder.files.remove(file.id);
  }

  @override
  Future<void> dispose() async {}
}

/// A simulated device: real database, real engine, fake transport.
class SimDevice {
  final String deviceId;
  final AppDatabase db;
  final TestDatabase? t;
  final FakeSyncTransport transport;
  final InMemoryPrefs prefs;
  final Directory dir;
  final SyncOutbox outbox;
  final SyncEngineConfig config;
  DateTime Function()? clock;
  late SyncEngine engine;

  SimDevice._(
    this.deviceId,
    this.db,
    this.t,
    this.transport,
    this.prefs,
    this.dir,
    this.outbox,
    this.config,
    this.clock,
  ) {
    engine = _newEngine();
  }

  SyncEngine _newEngine() => SyncEngine(
    db: db,
    transport: transport,
    deviceId: deviceId,
    outbox: outbox,
    prefs: prefs,
    config: config,
    clock: clock,
  );

  static Future<SimDevice> create(
    FakeSyncFolder folder, {
    SyncEngineConfig? config,
    QueryExecutor? executor,
    int pageSize = 100,
    Random? shuffle,
    DateTime Function()? clock,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('lz_sync_');
    final TestDatabase? t = executor == null ? TestDatabase() : null;
    final db = t?.db ?? AppDatabase(executor!);
    return SimDevice._(
      const Uuid().v4(),
      db,
      t,
      FakeSyncTransport(folder, pageSize: pageSize, shuffle: shuffle),
      InMemoryPrefs(),
      dir,
      SyncOutbox(() async => Directory('${dir.path}/outbox')),
      config ?? const SyncEngineConfig(kdfParams: fastKdf),
      clock,
    );
  }

  /// Replaces the database (restore simulation) and recreates the engine.
  SimDevice withDatabase(AppDatabase replacement) {
    final device = SimDevice._(
      deviceId,
      replacement,
      null,
      transport,
      prefs,
      dir,
      outbox,
      config,
      clock,
    );
    return device;
  }

  Future<SyncRunReport> sync() => engine.sync();

  Future<void> exec(String sql, [List<Object?> args = const []]) =>
      db.customStatement(sql, args);

  Future<List<Map<String, Object?>>> rows(String sql) async => [
    for (final r in await db.customSelect(sql).get()) r.data,
  ];

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.first as int;

  /// Canonical dump of every synced table (rows sorted by id).
  Future<String> dump() async {
    final buffer = StringBuffer();
    for (final table in [...AppDatabase.syncedTables]..sort()) {
      buffer.writeln('# $table');
      final rows = await db
          .customSelect('SELECT * FROM "$table" ORDER BY id')
          .get();
      for (final r in rows) {
        buffer.writeln(SyncSchema.canonicalJson(r.data));
      }
    }
    return buffer.toString();
  }

  Future<void> close() async {
    await db.close();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

/// Syncs every device [rounds] times (enough for all files to propagate).
Future<void> syncAll(List<SimDevice> devices, {int rounds = 2}) async {
  for (var i = 0; i < rounds; i++) {
    for (final d in devices) {
      await d.sync();
    }
  }
}
