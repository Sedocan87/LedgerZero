import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/utils/log_level.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/error/local_error_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lz_logger_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    LocalErrorReportingService().resetForTesting();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('warnings and errors are kept even with logging off (release '
      'builds), info is not', () async {
    // Release configuration: AppConfig is a singleton, so the first
    // configuration of the test process wins; it is logging-off in any
    // case.
    AppConfig(
      environment: AppEnvironment.production,
      appTitle: 'LedgerZero',
      enableLogging: false,
    );
    expect(AppConfig.instance.enableLogging, isFalse);

    Logger.info('booked 3 notifications');
    Logger.warning('capture storage was reset');
    Logger.error('Card notification n1 could not be booked', StateError('x'));
    // The writes are queued behind the service's lock.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final logs = await LocalErrorReportingService().getLogs();
    expect(logs.map((l) => l.level), [LogLevel.error, LogLevel.warning]);
    expect(logs.last.message, contains('capture storage was reset'));
    expect(logs.first.error, 'Bad state: x');
  });
}
