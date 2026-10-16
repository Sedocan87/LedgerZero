import 'dart:io';
import 'dart:typed_data';

import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Encrypted change files written by this device and not yet uploaded.
///
/// Files are written atomically (temporary file, flush, rename), so a crash
/// never leaves a truncated file that would be uploaded. Only names that
/// pass [SyncFileName.tryParse] are ever listed.
class SyncOutbox {
  final Future<Directory> Function() _root;

  SyncOutbox([Future<Directory> Function()? root])
    : _root = root ?? _defaultRoot;

  static Future<Directory> _defaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'sync', 'outbox'));
  }

  Directory? _dir;

  Future<Directory> _directory() async {
    final dir = _dir ??= await _root();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Writes [bytes] as [name], replacing an existing file of that name.
  Future<void> write(SyncFileName name, Uint8List bytes) async {
    final dir = await _directory();
    final target = File(p.join(dir.path, name.name));
    final temp = File('${target.path}.tmp');
    final raf = await temp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    await temp.rename(target.path);
  }

  /// Files waiting for upload, in sequence order.
  Future<List<(SyncFileName, File)>> pending() async {
    final dir = await _directory();
    final result = <(SyncFileName, File)>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = SyncFileName.tryParse(p.basename(entity.path));
      if (name != null) {
        result.add((name, entity));
      }
    }
    result.sort((a, b) {
      final byDevice = a.$1.deviceId.compareTo(b.$1.deviceId);
      return byDevice != 0 ? byDevice : a.$1.sequence.compareTo(b.$1.sequence);
    });
    return result;
  }

  Future<void> remove(SyncFileName name) async {
    final dir = await _directory();
    final file = File(p.join(dir.path, name.name));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes [deviceId]'s files with a sequence above [sequence] (left over
  /// from a generation whose database transaction did not commit) and stray
  /// temporary files.
  Future<void> removeAbove(String deviceId, int sequence) async {
    final dir = await _directory();
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final base = p.basename(entity.path);
      final name = SyncFileName.tryParse(base);
      final stale =
          base.endsWith('.tmp') ||
          (name != null &&
              (name.deviceId != deviceId || name.sequence > sequence));
      if (stale) {
        try {
          await entity.delete();
        } catch (e) {
          Logger.warning('Could not delete stale outbox file $base: $e');
        }
      }
    }
  }

  /// Deletes every queued file (after a restore, see SyncRebootstrap).
  Future<void> clear() async {
    final dir = await _directory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Removes the plaintext delta queue of sync format v1 (`deltas/`).
  static Future<void> removeLegacyQueue([Directory? documents]) async {
    try {
      final docs = documents ?? await getApplicationDocumentsDirectory();
      final legacy = Directory(p.join(docs.path, 'deltas'));
      if (await legacy.exists()) {
        await legacy.delete(recursive: true);
      }
    } catch (e) {
      Logger.warning('Could not remove the old delta queue: $e');
    }
  }
}
