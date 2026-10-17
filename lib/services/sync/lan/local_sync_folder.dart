import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ledger_zero/services/sync/format/sync_file_name.dart';

/// The sync folder of Wi-Fi sync, kept on this phone
/// (`<documents>/sync/lan`). The sync engine reads and writes it like the
/// Drive folder; the paired phones copy files between their folders.
///
/// Only sync file names ([isSyncFileName]) are listed, read or written.
/// Deleting a file (the engine compacts its own old change files) records
/// the name, so the paired phone can delete its copy too.
class LocalSyncFolder {
  LocalSyncFolder(this._directory);

  final Future<Directory> Function() _directory;

  static const String _deletedFile = '.deleted.json';
  static const int _maxDeleted = 5000;

  static bool isSyncFileName(String name) =>
      name == SyncFileName.manifest || SyncFileName.tryParse(name) != null;

  Future<Directory> _dir() async {
    final dir = await _directory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Name -> size of every sync file.
  Future<Map<String, int>> list() async {
    final dir = await _dir();
    final result = <String, int>{};
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      if (isSyncFileName(name)) {
        result[name] = await entity.length();
      }
    }
    return result;
  }

  Future<Uint8List?> read(String name) async {
    _check(name);
    final file = File('${(await _dir()).path}/$name');
    return await file.exists() ? file.readAsBytes() : null;
  }

  /// Writes [bytes] atomically (temporary file, then rename).
  Future<void> write(String name, Uint8List bytes) async {
    _check(name);
    final dir = await _dir();
    final temp = File('${dir.path}/.$name.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename('${dir.path}/$name');
  }

  /// Deletes [name]; with [record] the name is remembered (see class doc).
  Future<void> delete(String name, {bool record = false}) async {
    _check(name);
    final file = File('${(await _dir()).path}/$name');
    if (await file.exists()) {
      await file.delete();
    }
    if (record) {
      final deleted = await this.deleted();
      deleted.add(name);
      await _writeDeleted(deleted);
    }
  }

  /// Names this phone deleted on purpose (most recent last).
  Future<Set<String>> deleted() async {
    final file = File('${(await _dir()).path}/$_deletedFile');
    if (!await file.exists()) {
      return <String>{};
    }
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return {for (final n in list) n as String};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _writeDeleted(Set<String> names) async {
    final list = names.toList();
    final kept = list.length > _maxDeleted
        ? list.sublist(list.length - _maxDeleted)
        : list;
    final dir = await _dir();
    final temp = File('${dir.path}/$_deletedFile.part');
    await temp.writeAsString(jsonEncode(kept), flush: true);
    await temp.rename('${dir.path}/$_deletedFile');
  }

  /// Removes the folder (Wi-Fi sync turned off).
  Future<void> clear() async {
    final dir = await _directory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static void _check(String name) {
    if (!isSyncFileName(name)) {
      throw ArgumentError.value(name, 'name', 'not a sync file name');
    }
  }
}
