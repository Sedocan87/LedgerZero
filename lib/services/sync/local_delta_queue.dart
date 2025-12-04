import 'dart:convert';
import 'dart:io';

import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:path_provider/path_provider.dart';

class LocalDeltaQueue {
  final DeltaFilenameGenerator _filenameGenerator;

  LocalDeltaQueue(this._filenameGenerator);

  Future<Directory> get _deltasDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/deltas');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _uploadedDir async {
    final root = await _deltasDir;
    final dir = Directory('${root.path}/uploaded');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _incomingDir async {
    final root = await _deltasDir;
    final dir = Directory('${root.path}/incoming');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> get _appliedDir async {
    final root = await _deltasDir;
    final dir = Directory('${root.path}/applied');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> enqueue(SyncDelta delta) async {
    final dir = await _deltasDir;

    final filename = _filenameGenerator.generate(
      timestamp: delta.timestamp,
      deviceUuid: delta.deviceUuid,
      sequence: delta.sequence,
    );

    // Task 389: Compression
    // Use .json.gz extension
    final file = File('${dir.path}/$filename.json.gz');

    final jsonString = jsonEncode(delta.toJson());
    final bytes = utf8.encode(jsonString);
    final compressed = GZipCodec().encode(bytes);

    await file.writeAsBytes(compressed);

    return file;
  }

  Future<List<File>> getPendingDeltas() async {
    final dir = await _deltasDir;
    // List files, excluding directories (like 'uploaded', 'incoming', 'applied')
    // We only want files directly in 'deltas/' which are pending upload
    final entities = await dir.list().toList();
    final files = entities.whereType<File>().where((f) {
      return f.path.endsWith('.json.gz');
    }).toList();

    // Sort by name (which includes timestamp and sequence, so it keeps order)
    files.sort((a, b) => a.path.compareTo(b.path));

    return files;
  }

  Future<void> markAsUploaded(File file) async {
    final uploadedDir = await _uploadedDir;
    final filename = file.uri.pathSegments.last;
    final destination = '${uploadedDir.path}/$filename';
    await file.rename(destination);

    // Trigger cleanup (fire and forget with error logging)
    try {
      await cleanupOldUploadedDeltas(const Duration(days: 30));
    } catch (e, stack) {
      Logger.error('Error cleaning up old uploaded deltas', e, stack);
    }
  }

  Future<SyncDelta> readDelta(File file) async {
    final compressed = await file.readAsBytes();
    final bytes = GZipCodec().decode(compressed);
    final jsonString = utf8.decode(bytes);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return SyncDelta.fromJson(json);
  }

  Future<int> cleanupOldUploadedDeltas(Duration retentionPeriod) async {
    final uploadedDir = await _uploadedDir;
    final entities = await uploadedDir.list().toList();
    final now = DateTime.now();
    int deletedCount = 0;

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json.gz')) {
        final filename = entity.uri.pathSegments.last;
        // Filename format: timestamp_deviceUUID_sequence.json.gz
        // We handle .json.gz
        final nameWithoutExt = filename.replaceAll('.json.gz', '');
        final parts = nameWithoutExt.split('_');
        if (parts.isNotEmpty) {
          final timestampMs = int.tryParse(parts[0]);
          if (timestampMs != null) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
            if (now.difference(timestamp) > retentionPeriod) {
              await entity.delete();
              deletedCount++;
            }
          }
        }
      }
    }
    return deletedCount;
  }

  // --- Incoming Deltas Management (Task 443) ---

  /// Moves a downloaded file to the incoming queue.
  /// The file is expected to be a valid GZIP compressed JSON SyncDelta.
  /// Returns the file in its new location.
  Future<File> enqueueIncoming(File downloadedFile, String originalFilename) async {
    final incomingDir = await _incomingDir;
    final destination = File('${incomingDir.path}/$originalFilename');

    // If we already have it, overwrite it? Or skip?
    // Overwriting is safer to ensure we have the latest (though filenames are unique).
    if (await destination.exists()) {
      await destination.delete();
    }

    // Move the file
    await downloadedFile.copy(destination.path);
    // Optionally delete the original temp file if copy was used instead of move/rename
    // Depending on where downloadedFile is. If it's in temp, we should probably delete it or let OS handle it.
    // If the caller manages the downloaded file, we copy it.
    // Ideally we rename if on same volume, but copy is safer across volumes.

    return destination;
  }

  /// Gets all pending incoming deltas sorted by filename (timestamp/sequence).
  Future<List<File>> getPendingIncomingDeltas() async {
    final incomingDir = await _incomingDir;
    final entities = await incomingDir.list().toList();
    final files = entities.whereType<File>().where((f) {
      return f.path.endsWith('.json.gz');
    }).toList();

    // Sort by name (timestamp based)
    files.sort((a, b) => a.path.compareTo(b.path));

    return files;
  }

  /// Marks an incoming delta as applied by moving it to the applied folder.
  Future<void> markAsApplied(File file) async {
    final appliedDir = await _appliedDir;
    final filename = file.uri.pathSegments.last;
    final destination = '${appliedDir.path}/$filename';
    await file.rename(destination);

    // Trigger cleanup of applied deltas
    try {
      await cleanupOldAppliedDeltas(const Duration(days: 30));
    } catch (e, stack) {
      Logger.error('Error cleaning up old applied deltas', e, stack);
    }
  }

  Future<int> cleanupOldAppliedDeltas(Duration retentionPeriod) async {
    final appliedDir = await _appliedDir;
    final entities = await appliedDir.list().toList();
    final now = DateTime.now();
    int deletedCount = 0;

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json.gz')) {
        final filename = entity.uri.pathSegments.last;
        final nameWithoutExt = filename.replaceAll('.json.gz', '');
        final parts = nameWithoutExt.split('_');
        if (parts.isNotEmpty) {
          final timestampMs = int.tryParse(parts[0]);
          if (timestampMs != null) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
            if (now.difference(timestamp) > retentionPeriod) {
              await entity.delete();
              deletedCount++;
            }
          }
        }
      }
    }
    return deletedCount;
  }
}
