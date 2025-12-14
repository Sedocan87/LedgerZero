import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/sync_status.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';

class ICloudDriveService implements SyncTransport {
  final String containerId;
  ICloudStorage? _iCloudStorage;
  final StreamController<SyncState> _statusController =
      StreamController<SyncState>.broadcast();

  @override
  String get name => 'icloud';

  @override
  String get displayName => 'iCloud Drive';

  ICloudDriveService({
    this.containerId = 'iCloud.com.ledgerzero.app',
    ICloudStorage? storage,
  }) : _iCloudStorage = storage;

  Stream<SyncState> get status => _statusController.stream;

  @override
  Future<void> initialize() async {
    await _getStorage();
  }

  @override
  Future<void> dispose() async {
    await _statusController.close();
  }

  /// Initializes and returns the [ICloudStorage] instance.
  Future<ICloudStorage> _getStorage() async {
    if (_iCloudStorage != null) {
      return _iCloudStorage!;
    }
    try {
      _iCloudStorage = await ICloudStorage.getInstance(containerId);
      return _iCloudStorage!;
    } catch (e) {
      throw _handleError(e, 'Failed to initialize iCloud Storage');
    }
  }

  /// Verifies access to the iCloud container.
  Future<void> verifyContainerAccess() async {
    try {
      final storage = await _getStorage();
      // List files to ensure we have access.
      await storage.gatherFiles();
    } catch (e) {
      throw _handleError(e, 'Failed to access iCloud container');
    }
  }

  @override
  Future<String?> uploadDelta(File localFile, String filename) async {
    _updateStatus(
      SyncStatus.syncing,
      message: 'Uploading $filename',
      progress: 0,
    );
    try {
      final storage = await _getStorage();
      await storage.startUpload(
        filePath: localFile.path,
        destinationRelativePath: filename,
        onProgress: (stream) {
          stream.listen(
            (progress) {
              _updateStatus(
                SyncStatus.syncing,
                message: 'Uploading $filename',
                progress: progress,
              );
            },
            onError: (e) {
              // Handle stream error if needed, but startUpload exception handles main errors.
            },
            cancelOnError: true,
          );
        },
      );
      Logger.info('Uploaded delta to iCloud: $filename');
      _updateStatus(SyncStatus.idle);
      return filename; // iCloud doesn't give back an ID like Google Drive
    } catch (e) {
      _updateStatus(SyncStatus.error, message: 'Upload failed');
      throw _handleError(e, 'Failed to upload delta to iCloud');
    }
  }

  /// Uploads a backup file to iCloud Drive.
  Future<void> uploadBackup(File localFile, String filename) async {
    _updateStatus(
      SyncStatus.syncing,
      message: 'Uploading backup $filename',
      progress: 0,
    );
    try {
      final storage = await _getStorage();
      await storage.startUpload(
        filePath: localFile.path,
        destinationRelativePath: 'Backups/$filename',
        onProgress: (stream) {
          stream.listen(
            (progress) {
              _updateStatus(
                SyncStatus.syncing,
                message: 'Uploading backup $filename',
                progress: progress,
              );
            },
            onError: (e) {},
            cancelOnError: true,
          );
        },
      );
      Logger.info('Uploaded backup to iCloud: $filename');
      _updateStatus(SyncStatus.idle);
    } catch (e) {
      _updateStatus(SyncStatus.error, message: 'Backup upload failed');
      throw _handleError(e, 'Failed to upload backup to iCloud');
    }
  }

  @override
  Future<File> downloadDelta(RemoteFile remoteFile, String savePath) async {
    _updateStatus(
      SyncStatus.syncing,
      message: 'Downloading ${remoteFile.name}',
      progress: 0,
    );
    try {
      final storage = await _getStorage();
      await storage.startDownload(
        relativePath: remoteFile.name, // Use name as relative path
        destinationFilePath: savePath,
        onProgress: (stream) {
          stream.listen(
            (progress) {
              _updateStatus(
                SyncStatus.syncing,
                message: 'Downloading ${remoteFile.name}',
                progress: progress,
              );
            },
            onError: (e) {},
            cancelOnError: true,
          );
        },
      );
      _updateStatus(SyncStatus.idle);
      return File(savePath);
    } catch (e) {
      _updateStatus(SyncStatus.error, message: 'Download failed');
      throw _handleError(e, 'Failed to download delta from iCloud');
    }
  }

  @override
  Future<List<RemoteFile>> listDeltas() async {
    try {
      final storage = await _getStorage();
      final files = await storage.gatherFiles();
      return files
          .where((f) => f.relativePath.endsWith('.json.gz'))
          .map((f) => RemoteFile(f.relativePath, f.relativePath))
          .toList();
    } catch (e) {
      throw _handleError(e, 'Failed to list deltas from iCloud');
    }
  }

  /// Watches for changes in delta files in the iCloud container.
  /// Returns a stream of file names.
  Stream<List<String>> watchDeltas() async* {
    try {
      final storage = await _getStorage();
      // ignore: deprecated_member_use
      final stream = await storage.watchFiles();
      yield* stream.map((files) {
        return files.where((name) => name.endsWith('.json.gz')).toList();
      });
    } catch (e) {
      throw _handleError(e, 'Failed to watch deltas from iCloud');
    }
  }

  void _updateStatus(SyncStatus status, {String? message, double? progress}) {
    if (!_statusController.isClosed) {
      _statusController.add(
        SyncState(status: status, message: message, progress: progress),
      );
    }
  }

  SyncException _handleError(Object error, String defaultMessage) {
    if (error is PlatformException) {
      if (error.code == 'cloud_disabled') {
        return SyncException(
          'iCloud is disabled',
          originalError: error,
          retryable: false,
        );
      }
      // Check for quota/storage issues
      if (error.message?.toLowerCase().contains('quota') == true ||
          error.message?.toLowerCase().contains('full') == true) {
        return SyncException(
          'iCloud storage is full',
          originalError: error,
          retryable: false,
        );
      }
      // Network issues on iCloud are often handled by OS but if we see timeouts
      // we can mark them retryable.
      // Default to retryable for unknown platform exceptions as they might be transient.
      return SyncException(
        error.message ?? defaultMessage,
        originalError: error,
        retryable: true,
      );
    }
    return SyncException(
      defaultMessage,
      originalError: error,
      retryable: false,
    );
  }

  @override
  Future<void> deleteFile(String fileId) async {
    try {
      final storage = await _getStorage();
      await storage.delete(fileId);
      Logger.info('Deleted file from iCloud: $fileId');
    } catch (e) {
      Logger.error('Failed to delete file $fileId: $e');
      rethrow;
    }
  }
}
