import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/models/log_entry.dart';
import 'package:ledger_zero/services/error/diagnostic_environment.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

// Mock path provider
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return tempDir.path;
          },
        );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('error_test_');
    LocalErrorReportingService().resetForTesting();
  });

  tearDown(() async {
    LocalErrorReportingService.crashReportsEnabled = false;
    LocalErrorReportingService.loadEnvironment =
        DiagnosticEnvironment.fromPlatform;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('diagnostic report header', () {
    const pixel = DiagnosticEnvironment(
      appName: 'LedgerZero',
      version: '0.1.0',
      buildNumber: '7',
      androidSdk: 36,
      androidRelease: '16',
      deviceModel: 'Google Pixel 8',
      locale: 'de_DE',
      schemaVersion: AppDatabase.currentSchemaVersion,
    );
    const header =
        'App: LedgerZero 0.1.0 (build 7)\n'
        'Android: 16 (SDK 36)\n'
        'Device: Google Pixel 8\n'
        'Locale: de_DE\n'
        'Database schema: ${AppDatabase.currentSchemaVersion}';

    setUp(() {
      LocalErrorReportingService.loadEnvironment = () async => pixel;
    });

    test('names app version and build, Android, device, locale and schema '
        'with crash reports off and nothing logged', () async {
      LocalErrorReportingService.crashReportsEnabled = false;

      final report = await LocalErrorReportingService().buildDiagnosticReport();

      expect(report, startsWith('DIAGNOSTIC REPORT\n'));
      expect(report, contains(header));
      expect(report, endsWith(LocalErrorReportingService.nothingStoredLine));
    });

    test('comes before the log entries', () async {
      final service = LocalErrorReportingService();
      await service.log(
        LogEntry(
          timestamp: DateTime.utc(2026, 11, 10, 8),
          level: LogLevel.warning,
          message: 'Sync skipped',
        ),
      );

      final report = await service.buildDiagnosticReport();

      expect(report, startsWith('DIAGNOSTIC REPORT\n'));
      final headerAt = report.indexOf(header);
      final entryAt = report.indexOf(
        '[2026-11-10T08:00:00.000Z] WARNING: Sync skipped',
      );
      expect(headerAt, greaterThan(0));
      expect(entryAt, greaterThan(headerAt));
      expect(
        report,
        isNot(contains(LocalErrorReportingService.nothingStoredLine)),
      );
    });

    test('is still written when the platform does not answer', () async {
      // The real loader: no package_info or device_info plugin in a test.
      LocalErrorReportingService.loadEnvironment =
          DiagnosticEnvironment.fromPlatform;

      final report = await LocalErrorReportingService().buildDiagnosticReport();

      expect(report, contains('App: unavailable'));
      expect(report, contains('Locale: '));
      expect(
        report,
        contains('Database schema: ${AppDatabase.currentSchemaVersion}'),
      );
    });
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
      await file.writeAsString(
        '{"timestamp":"2023-01-01T00:00:00.000","level":"info","message":"old"}\n',
      );
    }

    // Verify initial state: 6 files exist
    var files = logDir.listSync().whereType<File>().toList();
    expect(files.length, 6);

    // Trigger log which should prune.
    await service.log(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'New message',
      ),
    );

    // Check files
    files = logDir
        .listSync()
        .whereType<File>()
        .where((f) => path.basename(f.path).startsWith('app_log_'))
        .toList();

    // Should be 5 files now
    expect(files.length, 5, reason: 'Should prune to max 5 files');

    // Oldest should be gone
    final oldestFile = File(path.join(logDir.path, fileNames[0]));
    expect(
      await oldestFile.exists(),
      false,
      reason: 'Oldest file should be deleted',
    );

    final lastFile = File(path.join(logDir.path, fileNames[5]));
    expect(await lastFile.exists(), true);

    final content = await lastFile.readAsString();
    expect(content.contains('New message'), true);
  });
}
