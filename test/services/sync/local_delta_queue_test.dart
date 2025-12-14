import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'local_delta_queue_test.mocks.dart';

@GenerateMocks([DeltaFilenameGenerator])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalDeltaQueue queue;
  late MockDeltaFilenameGenerator mockFilenameGenerator;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('delta_queue_test');

    // Mock path_provider
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);

    mockFilenameGenerator = MockDeltaFilenameGenerator();
    queue = LocalDeltaQueue(mockFilenameGenerator);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('enqueue compresses and writes file', () async {
    final delta = SyncDelta(
      timestamp: DateTime.now().toUtc(), // Use UTC to match expected output
      deviceUuid: 'uuid',
      sequence: 1,
      action: SyncAction.insert,
      tableName: 'accounts',
      data: const {'id': '1', 'name': 'Test'},
    );

    when(
      mockFilenameGenerator.generate(
        timestamp: anyNamed('timestamp'),
        deviceUuid: anyNamed('deviceUuid'),
        sequence: anyNamed('sequence'),
      ),
    ).thenReturn('test_delta');

    final file = await queue.enqueue(delta);

    expect(file.path, endsWith('test_delta.json.gz'));
    expect(await file.exists(), isTrue);

    // Verify content
    final bytes = await file.readAsBytes();
    // It should be GZIP compressed
    expect(
      () => utf8.decode(bytes),
      throwsException,
    ); // Should fail if valid gzip

    final decoded = await queue.readDelta(file);
    expect(decoded, equals(delta));
  });

  test('getPendingDeltas returns sorted files', () async {
    // create fake files
    final dir = Directory('${tempDir.path}/deltas');
    await dir.create(recursive: true);

    File('${dir.path}/2.json.gz').createSync();
    File('${dir.path}/1.json.gz').createSync();
    File('${dir.path}/not_a_delta.txt').createSync();
    Directory('${dir.path}/uploaded').createSync();

    final files = await queue.getPendingDeltas();
    expect(files.length, 2);
    expect(files[0].path, endsWith('1.json.gz'));
    expect(files[1].path, endsWith('2.json.gz'));
  });

  test('markAsUploaded moves file', () async {
    final dir = Directory('${tempDir.path}/deltas');
    await dir.create(recursive: true);
    final file = File('${dir.path}/test.json.gz');
    await file.create();

    await queue.markAsUploaded(file);

    expect(await file.exists(), isFalse);
    final uploadedFile = File('${dir.path}/uploaded/test.json.gz');
    expect(await uploadedFile.exists(), isTrue);
  });

  test('cleanupOldUploadedDeltas removes old files', () async {
    final dir = Directory('${tempDir.path}/deltas/uploaded');
    await dir.create(recursive: true);

    final now = DateTime.now();
    final oldTime = now.subtract(const Duration(days: 31));
    final newTime = now.subtract(const Duration(days: 1));

    // Old file
    final oldFilename = '${oldTime.millisecondsSinceEpoch}_uuid_1.json.gz';
    final oldFile = File('${dir.path}/$oldFilename');
    await oldFile.create();

    // New file
    final newFilename = '${newTime.millisecondsSinceEpoch}_uuid_2.json.gz';
    final newFile = File('${dir.path}/$newFilename');
    await newFile.create();

    // Random file that shouldn't be touched (bad format)
    final otherFile = File('${dir.path}/other.txt');
    await otherFile.create();

    final count = await queue.cleanupOldUploadedDeltas(
      const Duration(days: 30),
    );

    expect(count, 1);
    expect(await oldFile.exists(), isFalse);
    expect(await newFile.exists(), isTrue);
    expect(await otherFile.exists(), isTrue);
  });

  test(
    'enqueueIncoming moves file and getPendingIncomingDeltas returns sorted files',
    () async {
      // Simulate a downloaded file in a temp location
      final tempDownloadDir = Directory('${tempDir.path}/temp_downloads');
      await tempDownloadDir.create(recursive: true);

      final file1 = File('${tempDownloadDir.path}/2_delta.json.gz');
      await file1.create();

      final file2 = File('${tempDownloadDir.path}/1_delta.json.gz');
      await file2.create();

      await queue.enqueueIncoming(file1, '2_delta.json.gz');
      await queue.enqueueIncoming(file2, '1_delta.json.gz');

      final pending = await queue.getPendingIncomingDeltas();
      expect(pending.length, 2);
      expect(pending[0].path, endsWith('1_delta.json.gz'));
      expect(pending[1].path, endsWith('2_delta.json.gz'));
    },
  );

  test('markAsApplied moves file to applied', () async {
    // Manually create file in incoming since getPendingIncomingDeltas relies on it
    // But we can use enqueueIncoming to put it there
    final tempDownloadDir = Directory('${tempDir.path}/temp_downloads');
    await tempDownloadDir.create(recursive: true);
    final tempFile = File('${tempDownloadDir.path}/test_applied.json.gz');
    await tempFile.create();

    final file = await queue.enqueueIncoming(tempFile, 'test_applied.json.gz');

    await queue.markAsApplied(file);

    expect(await file.exists(), isFalse);
    final appliedFile = File(
      '${tempDir.path}/deltas/applied/test_applied.json.gz',
    );
    expect(await appliedFile.exists(), isTrue);
  });
}

class FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;

  FakePathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempPath;
  }
}
