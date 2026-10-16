import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:icloud_storage/icloud_storage_platform_interface.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';

/// Mimics icloud_storage: upload/download return at once; the transfer
/// finishes later and is signalled by the end of the progress stream.
class FakeICloudStorage implements ICloudStoragePlatform {
  final Map<String, Uint8List> container = {};
  Duration transferDelay = const Duration(milliseconds: 30);
  bool neverFinish = false;
  Object? streamError;

  @override
  Future<List<ICloudFile>> gather({
    required String containerId,
    StreamHandler<List<ICloudFile>>? onUpdate,
  }) async {
    return [
      for (final e in container.entries)
        ICloudFile.fromMap({
          'relativePath': e.key,
          'sizeInBytes': e.value.length,
          'creationDate': 1.0,
          'contentChangeDate': 2.0,
          'isDownloading': false,
          'downloadStatus': 'NSMetadataUbiquitousItemDownloadingStatusCurrent',
          'isUploading': false,
          'isUploaded': true,
          'hasUnresolvedConflicts': false,
        }),
    ];
  }

  @override
  Future<void> download({
    required String containerId,
    required String relativePath,
    required String destinationFilePath,
    StreamHandler<double>? onProgress,
  }) async {
    final controller = StreamController<double>();
    onProgress?.call(controller.stream);
    unawaited(() async {
      controller.add(10);
      if (neverFinish) {
        return;
      }
      await Future<void>.delayed(transferDelay);
      if (streamError != null) {
        controller.addError(streamError!);
        await controller.close();
        return;
      }
      await File(destinationFilePath).writeAsBytes(container[relativePath]!);
      controller.add(100);
      await controller.close();
    }());
  }

  @override
  Future<void> upload({
    required String containerId,
    required String filePath,
    required String destinationRelativePath,
    StreamHandler<double>? onProgress,
  }) async {
    // The plugin copies into the container synchronously.
    container[destinationRelativePath] = await File(filePath).readAsBytes();
    final controller = StreamController<double>();
    onProgress?.call(controller.stream);
    unawaited(() async {
      if (neverFinish) {
        return;
      }
      await Future<void>.delayed(transferDelay);
      controller.add(100);
      await controller.close();
    }());
  }

  @override
  Future<void> delete({
    required String containerId,
    required String relativePath,
  }) async {
    if (container.remove(relativePath) == null) {
      throw PlatformException(code: PlatformExceptionCode.fileNotFound);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeICloudStorage storage;
  late Directory temp;
  late ICloudDriveService service;

  setUp(() async {
    storage = FakeICloudStorage();
    temp = await Directory.systemTemp.createTemp('lz_icloud_');
    service = ICloudDriveService(
      platform: storage,
      tempDir: () async => temp,
      downloadTimeout: const Duration(milliseconds: 300),
      uploadTimeout: const Duration(milliseconds: 300),
    );
  });

  tearDown(() => temp.delete(recursive: true));

  test('download waits until the transfer has finished', () async {
    storage.container['a.lzsync'] = Uint8List.fromList(List.filled(1000, 7));
    final listed = await service.listFiles();
    expect(listed.single.size, 1000);
    final bytes = await service.download(listed.single);
    expect(bytes, hasLength(1000));
    // Temporary files are removed.
    final leftovers = Directory('${temp.path}/icloud_sync').listSync();
    expect(leftovers, isEmpty);
  });

  test('a download that never completes times out (retryable)', () async {
    storage.container['a.lzsync'] = Uint8List.fromList([1]);
    storage.neverFinish = true;
    await expectLater(
      service.download((await service.listFiles()).single),
      throwsA(
        isA<SyncException>().having((e) => e.retryable, 'retryable', true),
      ),
    );
  });

  test('size mismatches and stream errors are retryable failures', () async {
    storage.container['a.lzsync'] = Uint8List.fromList([1, 2, 3]);
    await expectLater(
      service.download(const RemoteFile('a.lzsync', 'a.lzsync', size: 99)),
      throwsA(
        isA<SyncException>().having((e) => e.retryable, 'retryable', true),
      ),
    );
    storage.streamError = PlatformException(code: 'E_NAT');
    await expectLater(
      service.download(const RemoteFile('a.lzsync', 'a.lzsync', size: 3)),
      throwsA(
        isA<SyncException>().having((e) => e.retryable, 'retryable', true),
      ),
    );
  });

  test('upload awaits the transfer; a slow one is left to iCloud', () async {
    await service.upload('b.lzsync', Uint8List.fromList([4, 5]));
    expect(storage.container['b.lzsync'], [4, 5]);
    storage.neverFinish = true;
    await service.upload('c.lzsync', Uint8List.fromList([6]));
    expect(storage.container['c.lzsync'], [6]);
  });

  test('only top-level files are listed; deletes are idempotent', () async {
    storage.container['Backups/x.lzbackup'] = Uint8List(1);
    storage.container['d.lzsync'] = Uint8List(1);
    final listed = await service.listFiles();
    expect(listed.map((f) => f.name), ['d.lzsync']);
    await service.delete(listed.single);
    await service.delete(listed.single);
  });

  test('missing container is permanent; network errors are not', () async {
    final denied = ICloudDriveService(
      platform: _ThrowingStorage(PlatformException(code: 'E_CTR')),
    );
    await expectLater(
      denied.listFiles(),
      throwsA(
        isA<SyncException>().having((e) => e.retryable, 'retryable', false),
      ),
    );
    final offline = ICloudDriveService(
      platform: _ThrowingStorage(const SocketException('offline')),
    );
    await expectLater(
      offline.listFiles(),
      throwsA(
        isA<SyncException>().having((e) => e.retryable, 'retryable', true),
      ),
    );
  });
}

class _ThrowingStorage implements ICloudStoragePlatform {
  final Object error;
  _ThrowingStorage(this.error);

  @override
  Future<List<ICloudFile>> gather({
    required String containerId,
    StreamHandler<List<ICloudFile>>? onUpdate,
  }) => Future.error(error);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
