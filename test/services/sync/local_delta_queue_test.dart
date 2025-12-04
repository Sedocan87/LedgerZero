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

    when(mockFilenameGenerator.generate(
      timestamp: anyNamed('timestamp'),
      deviceUuid: anyNamed('deviceUuid'),
      sequence: anyNamed('sequence'),
    )).thenReturn('test_delta');

    final file = await queue.enqueue(delta);

    expect(file.path, endsWith('test_delta.json.gz'));
    expect(await file.exists(), isTrue);

    // Verify content
    final bytes = await file.readAsBytes();
    // It should be GZIP compressed
    expect(() => utf8.decode(bytes), throwsException); // Should fail if valid gzip

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
}

class FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;

  FakePathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempPath;
  }
}
