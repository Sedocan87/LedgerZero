import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveService {
  final GoogleAuthService _authService;
  final SharedPreferences _prefs;
  String? _syncFolderId;
  static const String _folderIdKey = 'drive_sync_folder_id';

  GoogleDriveService(this._authService, this._prefs);

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      throw SyncException('User not signed in');
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

    // 1. Find or create LedgerZero root folder
    String? rootFolderId = await _findFolder(api, 'LedgerZero');
    rootFolderId ??= await _createFolder(api, 'LedgerZero');

    // 2. Find or create Sync folder inside LedgerZero
    String? syncFolderId =
        await _findFolder(api, 'Sync', parentId: rootFolderId);
    syncFolderId ??= await _createFolder(api, 'Sync', parentId: rootFolderId);

    _syncFolderId = syncFolderId;
    await _prefs.setString(_folderIdKey, syncFolderId);
    return syncFolderId;
  }

  Future<String?> _findFolder(drive.DriveApi api, String name,
      {String? parentId}) async {
    final query =
        "mimeType = 'application/vnd.google-apps.folder' and name = '$name' and trashed = false${parentId != null ? " and '$parentId' in parents" : ""}";
    final fileList = await api.files.list(q: query, spaces: 'drive');
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id;
    }
    return null;
  }

  Future<String> _createFolder(drive.DriveApi api, String name,
      {String? parentId}) async {
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';

    if (parentId != null) {
      folder.parents = [parentId];
    }

    final file = await api.files.create(folder);
    return file.id!;
  }

  Future<String?> uploadDelta(File localFile, String filename) async {
    return _retry(() async {
      final folderId = await ensureSyncFolderExists();
      final api = await _getDriveApi();

      final driveFile = drive.File()
        ..name = filename
        ..parents = [folderId];

      final media = drive.Media(localFile.openRead(), localFile.lengthSync());

      final result = await api.files.create(
        driveFile,
        uploadMedia: media,
      );

      Logger.info('Uploaded delta: $filename (ID: ${result.id})');
      return result.id;
    }, 'Failed to upload delta');
  }

  Future<File> downloadDelta(String fileId, String savePath) async {
    return _retry(() async {
      final api = await _getDriveApi();
      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final file = File(savePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final sink = file.openWrite();
      await media.stream.pipe(sink);

      Logger.info('Downloaded delta: $fileId to $savePath');
      return file;
    }, 'Failed to download delta');
  }

  Future<List<drive.File>> listDeltas() async {
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

      return fileList.files ?? [];
    }, 'Failed to list deltas');
  }

  Future<T> _retry<T>(
      Future<T> Function() operation, String errorMessage) async {
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
            'Retrying operation in ${delay.inSeconds}s (Attempt $attempts)');
        await Future.delayed(delay);
      }
    }
  }

  SyncException _handleError(Object error, String defaultMessage) {
    if (error is drive.DetailedApiRequestError) {
      final status = error.status;
      final isRetryable = status == 408 || // Request Timeout
          status == 429 || // Too Many Requests
          (status != null && status >= 500 && status < 600); // Server Error

      String message = defaultMessage;
      if (status == 403 &&
          error.message?.contains('usageLimits') == true) {
        message = 'Storage quota exceeded';
      } else if (status == 401) {
        message = 'Authentication failed. Please reconnect.';
      }

      return SyncException(
        message,
        originalError: error,
        isRetryable: isRetryable,
      );
    } else if (error is SocketException) {
      return SyncException(
        'Network error. Please check your connection.',
        originalError: error,
        isRetryable: true,
      );
    }
    return SyncException(defaultMessage, originalError: error);
  }

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
