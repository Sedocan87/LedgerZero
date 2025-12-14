import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/sync_status.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([ICloudStorage, ICloudFile])
import 'icloud_drive_service_test.mocks.dart';

void main() {
  late ICloudDriveService service;
  late MockICloudStorage mockStorage;

  setUp(() {
    mockStorage = MockICloudStorage();
    service = ICloudDriveService(storage: mockStorage);
  });

  tearDown(() {
    service.dispose();
  });

  group('verifyContainerAccess', () {
    test('should call gatherFiles on storage', () async {
      when(mockStorage.gatherFiles()).thenAnswer((_) async => []);

      await service.verifyContainerAccess();

      verify(mockStorage.gatherFiles()).called(1);
    });

    test('should throw SyncException on error', () async {
      when(
        mockStorage.gatherFiles(),
      ).thenThrow(PlatformException(code: 'error'));

      expect(
        () => service.verifyContainerAccess(),
        throwsA(isA<SyncException>()),
      );
    });

    test(
      'should throw SyncException with "iCloud storage is full" message on quota error',
      () async {
        when(mockStorage.gatherFiles()).thenThrow(
          PlatformException(code: 'error', message: 'Quota exceeded'),
        );

        try {
          await service.verifyContainerAccess();
          fail('Should have thrown SyncException');
        } on SyncException catch (e) {
          expect(e.message, 'iCloud storage is full');
        }
      },
    );
  });

  group('uploadDelta', () {
    test('should call startUpload on storage', () async {
      final file = File('test.json');
      when(
        mockStorage.startUpload(
          filePath: anyNamed('filePath'),
          destinationRelativePath: anyNamed('destinationRelativePath'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenAnswer((_) async {});

      await service.uploadDelta(file, 'test.json');

      verify(
        mockStorage.startUpload(
          filePath: file.path,
          destinationRelativePath: 'test.json',
          onProgress: anyNamed('onProgress'),
        ),
      ).called(1);
    });
  });

  group('downloadDelta', () {
    test('should call startDownload on storage', () async {
      when(
        mockStorage.startDownload(
          relativePath: anyNamed('relativePath'),
          destinationFilePath: anyNamed('destinationFilePath'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenAnswer((_) async {});

      await service.downloadDelta('test.json.gz', 'path/to/save');

      verify(
        mockStorage.startDownload(
          relativePath: 'test.json.gz',
          destinationFilePath: 'path/to/save',
          onProgress: anyNamed('onProgress'),
        ),
      ).called(1);
    });
  });

  group('listDeltas', () {
    test('should call gatherFiles and filter', () async {
      final mockFile1 = MockICloudFile();
      when(mockFile1.relativePath).thenReturn('test1.json.gz');

      final mockFile2 = MockICloudFile();
      when(mockFile2.relativePath).thenReturn('test2.txt');

      when(
        mockStorage.gatherFiles(),
      ).thenAnswer((_) async => [mockFile1, mockFile2]);

      final results = await service.listDeltas();

      verify(mockStorage.gatherFiles()).called(1);
      expect(results.length, 1);
      expect(results.first.relativePath, 'test1.json.gz');
    });
  });

  group('watchDeltas', () {
    test('should watch files and filter', () async {
      final streamController = StreamController<List<String>>();
      // ignore: deprecated_member_use
      when(
        mockStorage.watchFiles(),
      ).thenAnswer((_) async => streamController.stream);

      final stream = service.watchDeltas();

      final expectation = expectLater(
        stream,
        emitsInOrder([
          ['test1.json.gz'],
          isEmpty,
        ]),
      );

      streamController.add(['test1.json.gz', 'test2.txt']);
      streamController.add(['test3.txt']);

      await expectation;
      await streamController.close();
    });
  });

  group('status updates', () {
    test('uploadDelta emits syncing then idle', () async {
      final file = File('test.json');
      when(
        mockStorage.startUpload(
          filePath: anyNamed('filePath'),
          destinationRelativePath: anyNamed('destinationRelativePath'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final handler =
            invocation.namedArguments[#onProgress] as Function(Stream<double>)?;
        if (handler != null) {
          handler(Stream.fromIterable([0.5]));
        }
      });

      final states = <SyncState>[];
      final sub = service.status.listen(states.add);

      await service.uploadDelta(file, 'test.json');
      await Future.delayed(Duration.zero); // Let streams propagate

      expect(
        states.map((s) => s.status),
        containsAllInOrder([
          SyncStatus.syncing, // Initial 0 progress
          SyncStatus.syncing, // Progress 0.5
          SyncStatus.idle, // Complete
        ]),
      );

      await sub.cancel();
    });

    test('uploadDelta emits error on failure', () async {
      final file = File('test.json');
      when(
        mockStorage.startUpload(
          filePath: anyNamed('filePath'),
          destinationRelativePath: anyNamed('destinationRelativePath'),
          onProgress: anyNamed('onProgress'),
        ),
      ).thenThrow(PlatformException(code: 'error'));

      final states = <SyncState>[];
      final sub = service.status.listen(states.add);

      expect(
        () => service.uploadDelta(file, 'test.json'),
        throwsA(isA<SyncException>()),
      );
      await Future.delayed(Duration.zero);

      expect(
        states.map((s) => s.status),
        containsAllInOrder([SyncStatus.syncing, SyncStatus.error]),
      );

      await sub.cancel();
    });
  });
}
