import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';

import '../../helpers/sync_simulation.dart';
import '../../mocks/service_mocks.mocks.dart';

const folderMime = 'application/vnd.google-apps.folder';

class DriveEntry {
  final String id;
  final String name;
  final String? parent;
  final String? mimeType;
  Uint8List bytes;
  bool trashed = false;
  DriveEntry(this.id, this.name, this.parent, this.mimeType, this.bytes);
}

/// A fake Drive `files` resource: enough of list/create/get/update/delete
/// (query parsing, pagination, 404s, injected failures).
class FakeFiles implements drive.FilesResource {
  final Map<String, DriveEntry> entries = {};
  var _next = 0;
  final listCalls = <Map<String, Object?>>[];
  int creates = 0;

  /// The next create stores the file and then fails (a timed-out request
  /// that actually succeeded).
  bool failAfterNextCreate = false;

  /// The next request fails with this status.
  int? failNextWith;

  String addFolder(String name, {String? parent}) {
    final id = 'id${_next++}';
    entries[id] = DriveEntry(id, name, parent, folderMime, Uint8List(0));
    return id;
  }

  String addFile(String name, String parent, [List<int> bytes = const []]) {
    final id = 'id${_next++}';
    entries[id] = DriveEntry(id, name, parent, null, Uint8List.fromList(bytes));
    return id;
  }

  void _maybeFail() {
    final status = failNextWith;
    if (status != null) {
      failNextWith = null;
      throw drive.DetailedApiRequestError(status, 'injected');
    }
  }

  @override
  Future<drive.FileList> list({
    String? corpora,
    String? corpus,
    String? driveId,
    bool? includeItemsFromAllDrives,
    String? includeLabels,
    String? includePermissionsForView,
    bool? includeTeamDriveItems,
    String? orderBy,
    int? pageSize,
    String? pageToken,
    String? q,
    String? spaces,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    String? teamDriveId,
    String? $fields,
  }) async {
    _maybeFail();
    listCalls.add({'q': q, 'pageSize': pageSize, 'orderBy': orderBy});
    final name = RegExp(r"name = '([^']*)'").firstMatch(q ?? '')?.group(1);
    final parent = RegExp(
      r"'([^']*)' in parents",
    ).firstMatch(q ?? '')?.group(1);
    final folderOnly = (q ?? '').contains("mimeType = '$folderMime'");
    if (parent != null && !entries.containsKey(parent)) {
      throw drive.DetailedApiRequestError(404, 'File not found: $parent');
    }
    final matches = entries.values.where((e) {
      return !e.trashed &&
          (name == null || e.name == name) &&
          (parent == null || e.parent == parent) &&
          (!folderOnly || e.mimeType == folderMime);
    }).toList();
    if (orderBy == 'name') {
      matches.sort((a, b) => a.name.compareTo(b.name));
    }
    final size = pageSize ?? 100; // Drive's default page size
    final start = int.tryParse(pageToken ?? '') ?? 0;
    final page = matches.skip(start).take(size).toList();
    final more = start + size < matches.length;
    return drive.FileList(
      files: [
        for (final e in page)
          drive.File(
            id: e.id,
            name: e.name,
            size: '${e.bytes.length}',
            modifiedTime: DateTime.utc(2030),
          ),
      ],
      nextPageToken: more ? '${start + size}' : null,
    );
  }

  @override
  Future<drive.File> create(
    drive.File request, {
    bool? enforceSingleParent,
    bool? ignoreDefaultVisibility,
    String? includeLabels,
    String? includePermissionsForView,
    bool? keepRevisionForever,
    String? ocrLanguage,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    bool? useContentAsIndexableText,
    String? $fields,
    drive.UploadOptions uploadOptions = drive.UploadOptions.defaultOptions,
    drive.Media? uploadMedia,
  }) async {
    _maybeFail();
    final parent = request.parents?.single;
    if (parent != null && !entries.containsKey(parent)) {
      throw drive.DetailedApiRequestError(404, 'parent not found');
    }
    creates++;
    final bytes = <int>[];
    if (uploadMedia != null) {
      await for (final chunk in uploadMedia.stream) {
        bytes.addAll(chunk);
      }
    }
    final id = 'id${_next++}';
    entries[id] = DriveEntry(
      id,
      request.name!,
      parent,
      request.mimeType,
      Uint8List.fromList(bytes),
    );
    if (failAfterNextCreate) {
      failAfterNextCreate = false;
      throw TimeoutException('response lost');
    }
    return drive.File(id: id);
  }

  @override
  Future<Object> get(
    String fileId, {
    bool? acknowledgeAbuse,
    String? includeLabels,
    String? includePermissionsForView,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    String? $fields,
    drive.DownloadOptions downloadOptions = drive.DownloadOptions.metadata,
  }) async {
    _maybeFail();
    final e = entries[fileId];
    if (e == null) {
      throw drive.DetailedApiRequestError(404, 'File not found: $fileId');
    }
    if (downloadOptions == drive.DownloadOptions.fullMedia) {
      return drive.Media(Stream.value(e.bytes), e.bytes.length);
    }
    return drive.File(
      id: e.id,
      name: e.name,
      trashed: e.trashed,
      mimeType: e.mimeType,
    );
  }

  @override
  Future<drive.File> update(
    drive.File request,
    String fileId, {
    String? addParents,
    bool? enforceSingleParent,
    String? includeLabels,
    String? includePermissionsForView,
    bool? keepRevisionForever,
    String? ocrLanguage,
    String? removeParents,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    bool? useContentAsIndexableText,
    String? $fields,
    drive.UploadOptions uploadOptions = drive.UploadOptions.defaultOptions,
    drive.Media? uploadMedia,
  }) async {
    final e = entries[fileId]!;
    final bytes = <int>[];
    await for (final chunk in uploadMedia!.stream) {
      bytes.addAll(chunk);
    }
    e.bytes = Uint8List.fromList(bytes);
    return drive.File(id: fileId);
  }

  @override
  Future<void> delete(
    String fileId, {
    bool? enforceSingleParent,
    bool? supportsAllDrives,
    bool? supportsTeamDrives,
    String? $fields,
  }) async {
    if (entries.remove(fileId) == null) {
      throw drive.DetailedApiRequestError(404, 'File not found');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDriveApi implements drive.DriveApi {
  final FakeFiles fakeFiles;
  FakeDriveApi(this.fakeFiles);

  @override
  drive.FilesResource get files => fakeFiles;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFiles files;
  late InMemoryPrefs prefs;
  late int apiCreations;
  late GoogleDriveService service;

  GoogleDriveService newService() => GoogleDriveService(
    MockGoogleAuthService(),
    prefs,
    apiFactory: () async {
      apiCreations++;
      return FakeDriveApi(files);
    },
    retryDelay: (_) => Duration.zero,
  );

  setUp(() {
    files = FakeFiles();
    prefs = InMemoryPrefs();
    apiCreations = 0;
    service = newService();
  });

  String syncFolderId() => files.entries.values
      .singleWhere((e) => e.name == 'Sync' && !e.trashed)
      .id;

  test('lists every page, 1000 files per page, ordered by name', () async {
    await service.upload('first', Uint8List.fromList([1]));
    final folder = syncFolderId();
    for (var i = 0; i < 2500; i++) {
      files.addFile('file_${i.toString().padLeft(5, '0')}', folder);
    }
    files.listCalls.clear();
    final listed = await service.listFiles();
    expect(listed, hasLength(2501));
    final pages = files.listCalls
        .where((c) => (c['q'] as String).startsWith("'$folder' in parents"))
        .toList();
    expect(pages, hasLength(3));
    expect(pages.every((c) => c['pageSize'] == 1000), isTrue);
    expect(pages.every((c) => c['orderBy'] == 'name'), isTrue);
  });

  test('re-resolves the folder when the cached id is gone', () async {
    prefs.values['drive_sync_folder_id'] = 'deleted-folder';
    await service.upload('a', Uint8List.fromList([1, 2]));
    final folder = syncFolderId();
    expect(prefs.getString('drive_sync_folder_id'), folder);
    expect((await service.listFiles()).single.name, 'a');

    // The user deletes the folder while the app is running.
    files.entries.removeWhere((_, e) => e.id == folder || e.parent == folder);
    await service.upload('b', Uint8List.fromList([3]));
    expect(syncFolderId(), isNot(folder));
    expect((await service.listFiles()).map((f) => f.name), ['b']);
  });

  test('a trashed folder is not reused', () async {
    await service.upload('a', Uint8List.fromList([1]));
    final folder = syncFolderId();
    files.entries[folder]!.trashed = true;
    final fresh = newService();
    await fresh.upload('b', Uint8List.fromList([1]));
    expect(syncFolderId(), isNot(folder));
  });

  test('uploads are idempotent after a lost response', () async {
    files.failAfterNextCreate = true;
    await service.upload('x', Uint8List.fromList([1, 2, 3]));
    final named = files.entries.values.where((e) => e.name == 'x');
    expect(named, hasLength(1));

    // Same name, same size: kept; different content size: replaced.
    await service.upload('x', Uint8List.fromList([1, 2, 3]));
    await service.upload('x', Uint8List.fromList([9]));
    expect(files.entries.values.where((e) => e.name == 'x'), hasLength(1));
    final remote = (await service.listFiles()).single;
    expect(await service.download(remote), [9]);
  });

  test('an existing manifest is never replaced (creation race)', () async {
    const manifest = 'ledgerzero-sync-manifest.json';
    await service.upload(manifest, Uint8List.fromList([1, 2, 3]));
    await service.upload(manifest, Uint8List.fromList([9, 9, 9, 9, 9]));
    final remote = (await service.listFiles()).single;
    expect(await service.download(remote), [1, 2, 3]);
  });

  test('one cached client; 401 recreates it once', () async {
    await service.upload('a', Uint8List.fromList([1]));
    await service.listFiles();
    await service.listFiles();
    expect(apiCreations, 1);

    files.failNextWith = 401;
    await service.listFiles();
    expect(apiCreations, 2);

    service.resetClient();
    await service.listFiles();
    expect(apiCreations, 3);
  });

  test('transient errors are retried, permanent ones are not', () async {
    await service.upload('a', Uint8List.fromList([1]));
    files.failNextWith = 503;
    expect(await service.listFiles(), hasLength(1));
    files.failNextWith = 403;
    await expectLater(
      service.listFiles(),
      throwsA(
        isA<SyncException>().having((e) => e.retryable, 'retryable', false),
      ),
    );
  });

  test('incomplete downloads are rejected', () async {
    await service.upload('a', Uint8List.fromList([1, 2, 3]));
    final listed = (await service.listFiles()).single;
    final lying = RemoteFile(listed.name, listed.id, size: 10);
    await expectLater(service.download(lying), throwsA(isA<SyncException>()));
    // Deleting twice is fine.
    await service.delete(listed);
    await service.delete(listed);
  });
}
