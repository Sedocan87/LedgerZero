import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:icloud_storage/icloud_storage_platform_interface.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// iCloud Drive sync folder: the root of the app's ubiquity container
/// (backups go to `Backups/`).
///
/// `icloud_storage` completes `upload`/`download` before the transfer is
/// done; completion is only signalled by the end of the progress stream. This transport therefore always listens to that stream
/// and waits for it to finish (with a timeout), and verifies the size of
/// every download.
class ICloudDriveService implements SyncTransport {
  final String containerId;
  final ICloudStoragePlatform? _platform;
  final Future<Directory> Function() _tempDir;
  final Duration downloadTimeout;
  final Duration uploadTimeout;

  @override
  String get name => 'icloud';

  ICloudDriveService({
    this.containerId = 'iCloud.com.ledgerzero.app',
    this._platform,
    Future<Directory> Function()? tempDir,
    this.downloadTimeout = const Duration(minutes: 2),
    this.uploadTimeout = const Duration(seconds: 45),
  }) : _tempDir = tempDir ?? getTemporaryDirectory;

  @override
  Future<void> dispose() async {}

  /// The plugin's platform implementation (injectable for tests).
  ICloudStoragePlatform get _storage =>
      _platform ?? ICloudStoragePlatform.instance;

  Future<List<ICloudFile>> _gather() =>
      _storage.gather(containerId: containerId);

  /// Verifies access to the iCloud container.
  Future<void> verifyContainerAccess() async {
    try {
      await _gather();
    } catch (e) {
      throw _toSyncException(e, 'Failed to access iCloud container');
    }
  }

  @override
  Future<List<RemoteFile>> listFiles() async {
    try {
      final files = await _gather();
      return [
        for (final f in files)
          if (!f.relativePath.contains('/'))
            RemoteFile(
              f.relativePath,
              f.relativePath,
              size: f.sizeInBytes,
              modifiedTime: f.contentChangeDate.toUtc(),
            ),
      ];
    } catch (e) {
      throw _toSyncException(e, 'Failed to list the iCloud sync folder');
    }
  }

  @override
  Future<Uint8List> download(RemoteFile file) async {
    final temp = await _tempFile('download');
    try {
      final done = Completer<void>();
      await _storage.download(
        containerId: containerId,
        relativePath: file.id,
        destinationFilePath: temp.path,
        onProgress: (stream) => _completeOnDone(stream, done),
      );
      await done.future.timeout(downloadTimeout);
      if (!await temp.exists()) {
        throw SyncException(
          'iCloud did not deliver ${file.name}',
          retryable: true,
        );
      }
      final bytes = await temp.readAsBytes();
      if (file.size != null && bytes.length != file.size) {
        throw SyncException(
          'Incomplete iCloud download of ${file.name}',
          retryable: true,
        );
      }
      return bytes;
    } catch (e) {
      throw _toSyncException(e, 'Failed to download ${file.name} from iCloud');
    } finally {
      await _deleteQuietly(temp);
    }
  }

  @override
  Future<void> upload(String fileName, Uint8List bytes) async {
    final temp = await _tempFile('upload');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await _upload(temp, fileName);
    } finally {
      await _deleteQuietly(temp);
    }
  }

  /// Uploads a backup archive to `Backups/` in the container.
  Future<void> uploadBackup(File localFile, String filename) async {
    await _upload(localFile, 'Backups/$filename');
    Logger.info('Uploaded backup to iCloud: $filename');
  }

  Future<void> _upload(File local, String relativePath) async {
    try {
      final done = Completer<void>();
      // The plugin copies the file into the container before returning;
      // iCloud then uploads it in the background.
      await _storage.upload(
        containerId: containerId,
        filePath: local.path,
        destinationRelativePath: relativePath,
        onProgress: (stream) => _completeOnDone(stream, done),
      );
      try {
        await done.future.timeout(uploadTimeout);
      } on TimeoutException {
        // The file is in the ubiquity container; iCloud keeps uploading it
        // after we return (e.g. while offline). Nothing is lost.
        Logger.info('iCloud: $relativePath still uploading in the background');
      }
    } catch (e) {
      throw _toSyncException(e, 'Failed to upload $relativePath to iCloud');
    }
  }

  @override
  Future<void> delete(RemoteFile file) async {
    try {
      await _storage.delete(containerId: containerId, relativePath: file.id);
    } on PlatformException catch (e) {
      if (e.code == PlatformExceptionCode.fileNotFound) {
        return;
      }
      throw _toSyncException(e, 'Failed to delete ${file.name} from iCloud');
    } catch (e) {
      throw _toSyncException(e, 'Failed to delete ${file.name} from iCloud');
    }
  }

  static void _completeOnDone(Stream<double> stream, Completer<void> done) {
    stream.listen(
      (_) {},
      onError: (Object e) {
        if (!done.isCompleted) {
          done.completeError(e);
        }
      },
      onDone: () {
        if (!done.isCompleted) {
          done.complete();
        }
      },
      cancelOnError: true,
    );
  }

  Future<File> _tempFile(String purpose) async {
    final dir = Directory(p.join((await _tempDir()).path, 'icloud_sync'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final random = secureRandomBytes(
      8,
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return File(p.join(dir.path, '$purpose-$random.tmp'));
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Whether an error is worth retrying: missing container / not signed in /
  /// invalid arguments / missing file are permanent; native, network,
  /// timeout and file-system errors are transient.
  static SyncException _toSyncException(Object error, String message) {
    if (error is SyncException) {
      return error;
    }
    if (error is PlatformException) {
      final code = error.code;
      final text = (error.message ?? '').toLowerCase();
      if (code == PlatformExceptionCode.iCloudConnectionOrPermission) {
        return SyncException(
          'iCloud is not available (not signed in or iCloud Drive off)',
          originalError: error,
          kind: SyncErrorKind.iCloudUnavailable,
        );
      }
      if (text.contains('quota') || text.contains('full')) {
        return SyncException(
          'iCloud storage is full',
          originalError: error,
          kind: SyncErrorKind.storageFull,
        );
      }
      if (code == PlatformExceptionCode.fileNotFound || code == 'E_ARG') {
        return SyncException(message, originalError: error);
      }
      return SyncException(message, originalError: error, retryable: true);
    }
    if (error is InvalidArgumentException || error is ArgumentError) {
      return SyncException(message, originalError: error);
    }
    if (error is SocketException || error is TimeoutException) {
      return SyncException(
        message,
        originalError: error,
        retryable: true,
        kind: SyncErrorKind.network,
      );
    }
    if (error is FileSystemException) {
      return SyncException(message, originalError: error, retryable: true);
    }
    return SyncException(message, originalError: error, retryable: true);
  }
}
