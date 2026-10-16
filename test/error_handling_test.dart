import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/data/database/database_error_handler.dart';
import 'package:drift/native.dart';

void main() {
  group('DatabaseErrorHandler', () {
    test('should rethrow generic exception as DatabaseException', () async {
      final exception = Exception('Generic error');

      expect(
        () => DatabaseErrorHandler.execute(() async => throw exception),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('should rethrow SqliteException as DatabaseException', () async {
      final exception = SqliteException(
        extendedResultCode: 1,
        message: 'SQL error',
      );

      expect(
        () => DatabaseErrorHandler.execute(() async => throw exception),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
