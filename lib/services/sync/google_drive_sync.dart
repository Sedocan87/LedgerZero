import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' show AuthClient;
import 'package:http/http.dart' as http;
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Drive sync folder (`LedgerZero/Sync`) and backup folder
/// (`LedgerZero/Backups`), with the `drive.file` scope.
///
/// * One authenticated client per session, closed by [resetClient] (sign
///   out, 401) and [dispose].
/// * Folder ids are cached (memory and SharedPreferences) but validated once
///   per session and re-resolved when Drive answers 404 (folder trashed or
///   deleted by the user).
/// * Listing follows every page (`pageSize` 1000, ordered by name).
/// * Uploads are idempotent: the name is looked up before creating, so a
///   retry after a timed-out-but-successful create does not duplicate it.
class GoogleDriveService implements SyncTransport {
  final GoogleAuthService _authService;
  final SharedPreferences _prefs;
  final Future<drive.DriveApi> Function()? _apiFactory;
  final Duration Function(int attempt) _retryDelay;
  final Duration operationTimeout;

  static const String _folderIdKey = 'drive_sync_folder_id';
  static const String _backupsFolderIdKey = 'drive_backups_folder_id';
  static const String _folderMime = 'application/vnd.google-apps.folder';
  static const int pageSize = 1000;

  AuthClient? _client;
  drive.DriveApi? _api;
  final Map<String, String> _folderIds = {};
  final Set<String> _validatedFolders = {};

  @override
  String get name => 'google_drive';

  GoogleDriveService(
    this._authService,
    this._prefs, {
    this._apiFactory,
    Duration Function(int attempt)? retryDelay,
    this.operationTimeout = const Duration(minutes: 2),
  }) : _retryDelay =
           retryDelay ?? ((attempt) => Duration(seconds: 1 << attempt));

  /// Drops the cached client (after sign-out or an expired token).
  void resetClient() {
    _client?.close();
    _client = null;
    _api = null;
    _validatedFolders.clear();
  }

  @override
  Future<void> dispose() async => resetClient();

  Future<drive.DriveApi> _driveApi() async {
    final cached = _api;
    if (cached != null) {
      return cached;
    }
    final factory = _apiFactory;
    if (factory != null) {
      return _api = await factory();
    }
    final client = await _authService.getAuthenticatedClient();
    if (client == null) {
      throw const SyncException(
        'User not signed in',
        kind: SyncErrorKind.notSignedIn,
      );
    }
    _client = client;
    return _api = drive.DriveApi(client);
  }

  // --- folders ---

  Future<String> ensureSyncFolderExists() => _folder('Sync', _folderIdKey);

  Future<String> ensureBackupsFolderExists() =>
      _folder('Backups', _backupsFolderIdKey);

  Future<String> _folder(String folderName, String prefsKey) async {
    final api = await _driveApi();
    final cached = _folderIds[folderName] ?? _prefs.getString(prefsKey);
    if (cached != null) {
      if (_validatedFolders.contains(cached) ||
          await _folderUsable(api, cached)) {
        _validatedFolders.add(cached);
        _folderIds[folderName] = cached;
        return cached;
      }
      Logger.info('Drive folder $folderName is gone; resolving it again.');
      await _forgetFolder(folderName, prefsKey);
    }
    final root =
        await _findFolder(api, 'LedgerZero') ??
        await _createFolder(api, 'LedgerZero');
    final id =
        await _findFolder(api, folderName, parentId: root) ??
        await _createFolder(api, folderName, parentId: root);
    _folderIds[folderName] = id;
    _validatedFolders.add(id);
    await _prefs.setString(prefsKey, id);
    return id;
  }

  Future<void> _forgetFolder(String folderName, String prefsKey) async {
    final id = _folderIds.remove(folderName);
    _validatedFolders.remove(id);
    await _prefs.remove(prefsKey);
  }

  Future<bool> _folderUsable(drive.DriveApi api, String id) async {
    try {
      final file =
          await api.files.get(id, $fields: 'id, trashed, mimeType')
              as drive.File;
      return file.trashed != true && file.mimeType == _folderMime;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404) {
        return false;
      }
      rethrow;
    }
  }

  Future<String?> _findFolder(
    drive.DriveApi api,
    String folderName, {
    String? parentId,
  }) async {
    final query =
        "mimeType = '$_folderMime' and name = '${_escape(folderName)}' "
        'and trashed = false'
        "${parentId != null ? " and '${_escape(parentId)}' in parents" : ''}";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'createdTime',
      $fields: 'files(id)',
    );
    final files = list.files ?? const <drive.File>[];
    return files.isEmpty ? null : files.first.id;
  }

  Future<String> _createFolder(
    drive.DriveApi api,
    String folderName, {
    String? parentId,
  }) async {
    final folder = drive.File()
      ..name = folderName
      ..mimeType = _folderMime;
    if (parentId != null) {
      folder.parents = [parentId];
    }
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  /// Runs [op] with the sync folder id; if Drive reports 404 (the folder
  /// was deleted meanwhile) the folder is resolved again and [op] retried.
  Future<T> _inFolder<T>(
    String folderName,
    String prefsKey,
    Future<T> Function(drive.DriveApi api, String folderId) op,
  ) async {
    final api = await _driveApi();
    final folderId = await _folder(folderName, prefsKey);
    try {
      return await op(api, folderId);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 404) {
        rethrow;
      }
      await _forgetFolder(folderName, prefsKey);
      final again = await _folder(folderName, prefsKey);
      return op(await _driveApi(), again);
    }
  }

  // --- SyncTransport ---

  @override
  Future<List<RemoteFile>> listFiles() {
    return _retry('list the sync folder', () {
      return _inFolder('Sync', _folderIdKey, (api, folderId) async {
        final result = <RemoteFile>[];
        String? token;
        do {
          final page = await api.files.list(
            q: "'${_escape(folderId)}' in parents and trashed = false",
            spaces: 'drive',
            pageSize: pageSize,
            orderBy: 'name',
            pageToken: token,
            $fields: 'nextPageToken, files(id, name, size, modifiedTime)',
          );
          for (final f in page.files ?? const <drive.File>[]) {
            if (f.id == null || f.name == null) {
              continue;
            }
            result.add(
              RemoteFile(
                f.name!,
                f.id!,
                size: int.tryParse(f.size ?? ''),
                modifiedTime: f.modifiedTime?.toUtc(),
              ),
            );
          }
          token = page.nextPageToken;
        } while (token != null && token.isNotEmpty);
        return result;
      });
    });
  }

  @override
  Future<Uint8List> download(RemoteFile file) {
    return _retry('download ${file.name}', () async {
      final api = await _driveApi();
      final media =
          await api.files.get(
                file.id,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in media.stream) {
        builder.add(chunk);
      }
      final bytes = builder.toBytes();
      final expected = file.size ?? media.length;
      if (expected != null && expected != bytes.length) {
        throw SyncException(
          'Incomplete download of ${file.name}',
          retryable: true,
        );
      }
      return bytes;
    });
  }

  @override
  Future<void> upload(String fileName, Uint8List bytes) {
    return _retry('upload $fileName', () {
      return _inFolder('Sync', _folderIdKey, (api, folderId) {
        return _uploadInto(api, folderId, fileName, bytes);
      });
    });
  }

  Future<void> _uploadInto(
    drive.DriveApi api,
    String folderId,
    String fileName,
    Uint8List bytes,
  ) async {
    final existing = await api.files.list(
      q:
          "name = '${_escape(fileName)}' and '${_escape(folderId)}' in parents "
          'and trashed = false',
      spaces: 'drive',
      $fields: 'files(id, size)',
    );
    final files = existing.files ?? const <drive.File>[];
    if (files.isNotEmpty) {
      final current = files.first;
      if (int.tryParse(current.size ?? '') == bytes.length) {
        return; // already there (e.g. a retried create that succeeded)
      }
      await api.files.update(
        drive.File(),
        current.id!,
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      );
      return;
    }
    final metadata = drive.File()
      ..name = fileName
      ..parents = [folderId];
    await api.files.create(
      metadata,
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
      $fields: 'id',
    );
  }

  @override
  Future<void> delete(RemoteFile file) {
    return _retry('delete ${file.name}', () async {
      final api = await _driveApi();
      try {
        await api.files.delete(file.id);
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status != 404) {
          rethrow;
        }
      }
    });
  }

  /// Uploads a backup archive to `LedgerZero/Backups`.
  Future<void> uploadBackup(File localFile, String filename) async {
    final bytes = await localFile.readAsBytes();
    await _retry('upload backup $filename', () {
      return _inFolder('Backups', _backupsFolderIdKey, (api, folderId) {
        return _uploadInto(api, folderId, filename, bytes);
      });
    });
    Logger.info('Uploaded backup: $filename');
  }

  // --- errors ---

  Future<T> _retry<T>(String what, Future<T> Function() op) async {
    var attempt = 0;
    var reauthenticated = false;
    while (true) {
      attempt++;
      try {
        return await op().timeout(operationTimeout);
      } catch (e) {
        if (!reauthenticated &&
            e is drive.DetailedApiRequestError &&
            e.status == 401) {
          reauthenticated = true;
          resetClient();
          continue;
        }
        final error = _toSyncException(e, 'Failed to $what');
        if (attempt >= 3 || !error.retryable) {
          Logger.error('Drive: failed to $what: $e');
          throw error;
        }
        await Future<void>.delayed(_retryDelay(attempt));
      }
    }
  }

  static SyncException _toSyncException(Object error, String message) {
    if (error is SyncException) {
      return error;
    }
    if (error is drive.DetailedApiRequestError) {
      final status = error.status;
      final retryable =
          status == 408 ||
          status == 429 ||
          (status == 403 && (error.message ?? '').contains('rateLimit')) ||
          (status != null && status >= 500 && status < 600);
      var text = message;
      var kind = SyncErrorKind.other;
      if (status == 403 && (error.message ?? '').contains('storageQuota')) {
        text = 'Google Drive storage is full';
        kind = SyncErrorKind.storageFull;
      } else if (status == 401) {
        text = 'Google authentication failed';
        kind = SyncErrorKind.authFailed;
      }
      return SyncException(
        text,
        originalError: error,
        retryable: retryable,
        kind: kind,
      );
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException ||
        error is HandshakeException) {
      return SyncException(
        'Network error',
        originalError: error,
        retryable: true,
        kind: SyncErrorKind.network,
      );
    }
    return SyncException(message, originalError: error);
  }

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
