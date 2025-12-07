import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/data/models/log_entry.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

// Mock path provider
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return tempDir.path;
    });
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('error_test_');
    LocalErrorReportingService().resetForTesting();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('LocalErrorReportingService writes logs and reads them back', () async {
    final service = LocalErrorReportingService();

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      message: 'Test message',
    );

    await service.log(entry);

    final logs = await service.getLogs();
    expect(logs.length, 1);
    expect(logs.first.message, 'Test message');
    expect(logs.first.level, LogLevel.info);
  });

  test('LocalErrorReportingService rotates logs', () async {
    final service = LocalErrorReportingService();

    // We need to create the logs directory first because the service expects it or creates it
    // But since we are manually creating files to simulate old logs, we must put them in the right place.
    // The service uses 'logs' subdirectory.
    final logDir = Directory(path.join(tempDir.path, 'logs'));
    await logDir.create();

    final fileNames = List.generate(6, (i) => 'app_log_${1000 + i}.jsonl');

    for (var name in fileNames) {
       final file = File(path.join(logDir.path, name));
       await file.writeAsString('{"timestamp":"2023-01-01T00:00:00.000","level":"info","message":"old"}\n');
    }

    // Verify initial state: 6 files exist
    var files = logDir.listSync().whereType<File>().toList();
    expect(files.length, 6);

    // Trigger log which should prune.
    await service.log(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      message: 'New message',
    ));

    // Check files
    files = logDir.listSync().whereType<File>().where((f) => path.basename(f.path).startsWith('app_log_')).toList();

    // Should be 5 files now
    expect(files.length, 5, reason: 'Should prune to max 5 files');

    // Oldest should be gone
    final oldestFile = File(path.join(logDir.path, fileNames[0]));
    expect(await oldestFile.exists(), false, reason: 'Oldest file should be deleted');

    final lastFile = File(path.join(logDir.path, fileNames[5]));
    expect(await lastFile.exists(), true);

    final content = await lastFile.readAsString();
    expect(content.contains('New message'), true);
  });
}
