import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveService implements SyncTransport {
  final GoogleAuthService _authService;
  final SharedPreferences _prefs;
  String? _syncFolderId;
  String? _backupsFolderId;
  static const String _folderIdKey = 'drive_sync_folder_id';
  static const String _backupsFolderIdKey = 'drive_backups_folder_id';

  @override
  String get name => 'google_drive';

  @override
  String get displayName => 'Google Drive';

  GoogleDriveService(this._authService, this._prefs);

  @override
  Future<void> initialize() async {
    // Check if we have credentials?
    // GoogleDriveService relies on on-demand auth via methods.
    // We can check if signed in silently.
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      // Maybe try sign in silently?
      // For now, strict:
      // throw const SyncException('User not signed in', retryable: false);
    }
  }

  @override
  Future<void> dispose() async {
    // No-op
  }

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      throw const SyncException('User not signed in', retryable: false);
    }
    return drive.DriveApi(client);
  }

  Future<String> ensureSyncFolderExists() async {
    if (_syncFolderId != null) {
      return _syncFolderId!;
    }
    // Check persistent cache
    final cachedId = _prefs.getString(_folderIdKey);
    if (cachedId != null) {
      _syncFolderId = cachedId;
      return cachedId;
    }
    final api = await _getDriveApi();
    final rootFolderId = await _ensureRootFolderExists(api);

    String? syncFolderId = await _findFolder(
      api,
      'Sync',
      parentId: rootFolderId,
    );
    syncFolderId ??= await _createFolder(api, 'Sync', parentId: rootFolderId);

    _syncFolderId = syncFolderId;
    await _prefs.setString(_folderIdKey, syncFolderId);
    return syncFolderId;
  }

  Future<String> ensureBackupsFolderExists() async {
    if (_backupsFolderId != null) {
      return _backupsFolderId!;
    }
    // Check persistent cache
    final cachedId = _prefs.getString(_backupsFolderIdKey);
    if (cachedId != null) {
      _backupsFolderId = cachedId;
      return cachedId;
    }

    final api = await _getDriveApi();
    final rootFolderId = await _ensureRootFolderExists(api);

    String? backupsFolderId = await _findFolder(
      api,
      'Backups',
      parentId: rootFolderId,
    );
    backupsFolderId ??= await _createFolder(
      api,
      'Backups',
      parentId: rootFolderId,
    );

    _backupsFolderId = backupsFolderId;
    await _prefs.setString(_backupsFolderIdKey, backupsFolderId);
    return backupsFolderId;
  }

  Future<String> _ensureRootFolderExists(drive.DriveApi api) async {
    String? rootFolderId = await _findFolder(api, 'LedgerZero');
    rootFolderId ??= await _createFolder(api, 'LedgerZero');
    return rootFolderId;
  }

  Future<String?> _findFolder(
    drive.DriveApi api,
    String name, {
    String? parentId,
  }) async {
    final query =
        "mimeType = 'application/vnd.google-apps.folder' and name = '$name' and trashed = false${parentId != null ? " and '$parentId' in parents" : ""}";
    final fileList = await api.files.list(q: query, spaces: 'drive');
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }
    return null;
  }

  Future<String> _createFolder(
    drive.DriveApi api,
    String name, {
    String? parentId,
  }) async {
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';

    if (parentId != null) {
      folder.parents = [parentId];
    }

    final file = await api.files.create(folder);
    return file.id!;
  }

  @override
  Future<String?> uploadDelta(File localFile, String filename) async {
    return _retry(() async {
      final folderId = await ensureSyncFolderExists();
      final api = await _getDriveApi();

      final driveFile = drive.File()
        ..name = filename
        ..parents = [folderId];

      final media = drive.Media(localFile.openRead(), localFile.lengthSync());

      final result = await api.files.create(driveFile, uploadMedia: media);

      Logger.info('Uploaded delta: $filename (ID: ${result.id})');
      return result.id;
    }, 'Failed to upload delta');
  }

  Future<String?> uploadBackup(File localFile, String filename) async {
    return _retry(() async {
      final folderId = await ensureBackupsFolderExists();
      final api = await _getDriveApi();

      final driveFile = drive.File()
        ..name = filename
        ..parents = [folderId];

      final media = drive.Media(localFile.openRead(), localFile.lengthSync());

      final result = await api.files.create(driveFile, uploadMedia: media);

      Logger.info('Uploaded backup: $filename (ID: ${result.id})');
      return result.id;
    }, 'Failed to upload backup');
  }

  @override
  Future<File> downloadDelta(RemoteFile remoteFile, String savePath) async {
    return _retry(() async {
      final api = await _getDriveApi();
      final media =
          await api.files.get(
                remoteFile.id,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final file = File(savePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final sink = file.openWrite();
      await media.stream.pipe(sink);

      Logger.info('Downloaded delta: ${remoteFile.name} to $savePath');
      return file;
    }, 'Failed to download delta');
  }

  @override
  Future<List<RemoteFile>> listDeltas() async {
    return _retry(() async {
      final folderId = await ensureSyncFolderExists();
      final api = await _getDriveApi();

      final query = "'$folderId' in parents and trashed = false";
      final fileList = await api.files.list(
        q: query,
        spaces: 'drive',
        $fields:
            'files(id, name, createdTime, modifiedTime, size, md5Checksum)',
      );

      return (fileList.files ?? [])
          .map((f) => RemoteFile(f.name!, f.id!))
          .toList();
    }, 'Failed to list deltas');
  }

  Future<T> _retry<T>(
    Future<T> Function() operation,
    String errorMessage,
  ) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await operation();
      } catch (e) {
        final syncEx = _handleError(e, errorMessage);
        if (attempts >= 3 || !syncEx.isRetryable) {
          Logger.error('$errorMessage: $e');
          throw syncEx;
        }
        final delay = Duration(seconds: 1 << attempts);
        Logger.info(
          'Retrying operation in ${delay.inSeconds}s (Attempt $attempts)',
        );
        await Future.delayed(delay);
      }
    }
  }

  SyncException _handleError(Object error, String defaultMessage) {
    if (error is drive.DetailedApiRequestError) {
      final status = error.status;
      final isRetryable =
          status == 408 || // Request Timeout
          status == 429 || // Too Many Requests
          (status != null && status >= 500 && status < 600); // Server Error

      String message = defaultMessage;
      if (status == 403 && error.message?.contains('usageLimits') == true) {
        message = 'Storage quota exceeded';
      } else if (status == 401) {
        message = 'Authentication failed. Please reconnect.';
      }

      return SyncException(
        message,
        originalError: error,
        retryable: isRetryable,
      );
    } else if (error is SocketException) {
      return SyncException(
        'Network error. Please check your connection.',
        originalError: error,
        retryable: true,
      );
    }
    return SyncException(defaultMessage, originalError: error);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    try {
      final api = await _getDriveApi();
      await api.files.delete(fileId);
      Logger.info('Deleted file: $fileId');
    } catch (e) {
      Logger.error('Failed to delete file $fileId: $e');
      rethrow;
    }
  }
}
