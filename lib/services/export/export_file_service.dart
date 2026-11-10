import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands files to the system share sheet. Replaceable in tests.
abstract class FileSharer {
  /// Returns false when the user dismissed the share sheet without choosing
  /// a target (true when the platform cannot tell).
  Future<bool> share(List<String> paths, {String? text, String? subject});
}

class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<bool> share(
    List<String> paths, {
    String? text,
    String? subject,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        files: [for (final path in paths) XFile(path)],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

/// Saves a file where the user picks, through the system's "create
/// document" picker (Android's Storage Access Framework): a local folder,
/// a USB stick, or a cloud app's provider (Drive, Dropbox, ...). The app
/// signs in to nothing; the provider app does the upload. Replaceable in
/// tests.
abstract class FileSaver {
  /// Returns false when the user cancelled the picker.
  Future<bool> save(String filename, Uint8List bytes);
}

class SystemFileSaver implements FileSaver {
  const SystemFileSaver();

  @override
  Future<bool> save(String filename, Uint8List bytes) async {
    final saved = await FilePicker.saveFile(fileName: filename, bytes: bytes);
    return saved != null;
  }
}

/// Writes exported files (CSV, JSON, PDF, images, backups, diagnostic logs)
/// where they do not linger, and shares or saves them.
///
/// * Files go to `<temporary dir>/exports`: iOS `tmp/` and Android
///   `cacheDir` are excluded from device backups and from the Files app,
///   unlike the Documents directory.
/// * After the share sheet completes, the file is deleted. On Android the
///   receiving app may still be reading the content URI when the sheet
///   returns, so deletion there waits [androidDeleteDelay].
/// * [sweepStale] (run at start-up and on resume) deletes anything older
///   than an hour that survived a crash or a killed process.
class ExportFileService {
  static const String directoryName = 'exports';
  static const Duration staleAfter = Duration(hours: 1);
  static const Duration androidDeleteDelay = Duration(seconds: 60);

  final FileSharer _sharer;
  final FileSaver _saver;
  final Future<Directory> Function() _baseDirectory;
  final bool _deferDeletion;

  ExportFileService({
    FileSharer? sharer,
    FileSaver? saver,
    Future<Directory> Function()? baseDirectory,
    bool? deferDeletion,
  }) : _sharer = sharer ?? const SharePlusFileSharer(),
       _saver = saver ?? const SystemFileSaver(),
       _baseDirectory = baseDirectory ?? getTemporaryDirectory,
       _deferDeletion =
           deferDeletion ?? defaultTargetPlatform == TargetPlatform.android;

  Future<Directory> exportDirectory() async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, directoryName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// A path for a new export file named [filename] (no directories).
  Future<File> newFile(String filename) async {
    final dir = await exportDirectory();
    return File(p.join(dir.path, p.basename(filename)));
  }

  Future<File> writeString(String filename, String contents) async {
    final file = await newFile(filename);
    await file.writeAsString(contents, flush: true);
    return file;
  }

  Future<File> writeBytes(String filename, List<int> bytes) async {
    final file = await newFile(filename);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Shares [file] and deletes it afterwards (also if sharing fails).
  /// Returns false when the user dismissed the share sheet.
  Future<bool> shareAndDelete(
    File file, {
    String? text,
    String? subject,
  }) async {
    try {
      return await ExternalUiGuard.run(
        () => _sharer.share([file.path], text: text, subject: subject),
      );
    } finally {
      if (_deferDeletion) {
        unawaited(
          Future<void>.delayed(androidDeleteDelay, () => _delete(file)),
        );
      } else {
        await _delete(file);
      }
    }
  }

  /// Lets the user save [file] through the system file picker ("Save
  /// to…") and deletes it afterwards (also if saving fails). The picker
  /// writes a copy, so the file is deleted at once. Returns false when the
  /// user cancelled.
  Future<bool> saveAndDelete(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await ExternalUiGuard.run(
        () => _saver.save(p.basename(file.path), bytes),
      );
    } finally {
      await _delete(file);
    }
  }

  /// Deletes exports older than [maxAge]. Returns how many were removed.
  Future<int> sweepStale({Duration maxAge = staleAfter, DateTime? now}) async {
    try {
      return await _sweep(maxAge, now);
    } catch (_) {
      return 0; // Best effort; never fails the caller.
    }
  }

  Future<int> _sweep(Duration maxAge, DateTime? now) async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, directoryName));
    if (!await dir.exists()) {
      return 0;
    }
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }
      try {
        if ((await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
          removed++;
        }
      } catch (_) {
        // In use or already gone.
      }
    }
    return removed;
  }

  /// Deletes every export (factory reset).
  Future<void> deleteAll() async {
    final base = await _baseDirectory();
    final dir = Directory(p.join(base.path, directoryName));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      Logger.warning('Could not delete an exported file');
    }
  }
}
