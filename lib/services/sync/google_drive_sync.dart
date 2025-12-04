import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';

class GoogleDriveService {
  final GoogleAuthService _authService;
  String? _syncFolderId;

  GoogleDriveService(this._authService);

  Future<drive.DriveApi> _getDriveApi() async {
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      throw Exception('User not signed in');
    }
    return drive.DriveApi(client);
  }

  Future<String> ensureSyncFolderExists() async {
    if (_syncFolderId != null) {
      return _syncFolderId!;
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
    try {
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
    } catch (e) {
      Logger.error('Failed to upload delta $filename: $e');
      rethrow;
    }
  }

  Future<File> downloadDelta(String fileId, String savePath) async {
    try {
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
    } catch (e) {
      Logger.error('Failed to download delta $fileId: $e');
      rethrow;
    }
  }

  Future<List<drive.File>> listDeltas() async {
    try {
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
    } catch (e) {
      Logger.error('Failed to list deltas: $e');
      rethrow;
    }
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
