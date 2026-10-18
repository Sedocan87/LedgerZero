import 'dart:io';

import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:path/path.dart' as p;

/// Prefixes of the work directories `RestoreService` creates in the
/// temporary directory (deleted after a restore; leftovers after a crash).
const restoreWorkDirectoryPrefixes = ['restore_', 'selective_'];

/// Prefix of the copies `PickedFile.toLocalFile` writes.
const pickedFilePrefix = 'picked_';

/// Settings > Clear cache: deletes the app's own temporary files (exports,
/// restore work directories, copies of picked files). Not the whole
/// temporary directory: plugins and the Flutter engine keep files there.
Future<void> clearAppCache({
  required Directory tempDir,
  required ExportFileService exports,
}) async {
  await exports.deleteAll();
  if (!await tempDir.exists()) {
    return;
  }
  await for (final entity in tempDir.list()) {
    final name = p.basename(entity.path);
    if (entity is Directory &&
        restoreWorkDirectoryPrefixes.any(name.startsWith)) {
      await entity.delete(recursive: true);
    } else if (entity is File && name.startsWith(pickedFilePrefix)) {
      await entity.delete();
    }
  }
}
