import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';
import 'package:ledger_zero/services/error/log_scrubber.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LogScrubber', () {
    test('removes SQL statements and bound parameters', () {
      const message =
          'SqliteException(2067): while executing statement, UNIQUE '
          'constraint failed: payees.name\n'
          '  Causing statement: INSERT INTO payees (id, name) VALUES (?, ?), '
          'parameters: p1, Dr. Smith Clinic';
      final scrubbed = LogScrubber.scrub(message);
      expect(scrubbed, contains('UNIQUE constraint failed'));
      expect(scrubbed, isNot(contains('INSERT')));
      expect(scrubbed, isNot(contains('Dr. Smith')));
    });

    test('removes e-mail addresses, payloads and amounts', () {
      final scrubbed = LogScrubber.scrub(
        'Sync failed for jane.doe@example.com with delta '
        '{table: transactions, data: {amount: -125000, memo: Rent}} '
        'balance 1,234.56 EUR and 12.50 and list [1, 2, 3]',
      );
      expect(scrubbed, isNot(contains('jane.doe')));
      expect(scrubbed, isNot(contains('Rent')));
      expect(scrubbed, isNot(contains('125000')));
      expect(scrubbed, isNot(contains('1,234.56')));
      expect(scrubbed, isNot(contains('12.50')));
      expect(scrubbed, contains('<email>'));
      expect(scrubbed, contains('Sync failed'));
    });
  });

  group('crash reports', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('lz_crash_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => dir.path,
          );
      SharedPreferences.setMockInitialValues({});
      LocalErrorReportingService().resetForTesting();
    });

    tearDown(() async {
      LocalErrorReportingService.crashReportsEnabled = false;
      await dir.delete(recursive: true);
    });

    TestWidgetsFlutterBinding.ensureInitialized();

    test('are not written unless the user opted in', () async {
      LocalErrorReportingService.crashReportsEnabled = false;
      await LocalErrorReportingService().generateCrashReport(
        Exception('boom 1250.00'),
        StackTrace.current,
      );
      expect(dir.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test(
      'are scrubbed, stored in the cache directory and can be shared and deleted',
      () async {
        LocalErrorReportingService.crashReportsEnabled = true;
        final service = LocalErrorReportingService();
        await service.generateCrashReport(
          Exception(
            'Insert failed, parameters: Rent, -1250.00, owner@example.com',
          ),
          StackTrace.current,
        );

        final files = dir.listSync(recursive: true).whereType<File>().toList();
        expect(files, isNotEmpty);
        final report = await service.buildDiagnosticReport();
        expect(report, contains('CRASH REPORT'));
        expect(report, isNot(contains('Rent')));
        expect(report, isNot(contains('1250')));
        expect(report, isNot(contains('owner@example.com')));

        await service.deleteAll();
        expect(await service.buildDiagnosticReport(), isEmpty);
      },
    );
  });
}
