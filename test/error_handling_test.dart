import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/data/database/database_error_handler.dart';
import 'package:ledger_zero/services/sync/network_error_handler.dart';
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
      final exception = SqliteException(1, 'SQL error');

      expect(
        () => DatabaseErrorHandler.execute(() async => throw exception),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('NetworkErrorHandler', () {
    test('should wrap generic error in SyncException', () {
      final exception = Exception('Network failure');
      final result = NetworkErrorHandler.handle(exception);

      expect(result, isA<SyncException>());
      expect(result.message, contains('Network failure'));
      expect(result.retryable, isTrue);
    });

    test('should return SyncException as is', () {
      final exception = SyncException('Auth failed', retryable: false);
      final result = NetworkErrorHandler.handle(exception);

      expect(result, equals(exception));
      expect(result.retryable, isFalse);
    });
  });
}
