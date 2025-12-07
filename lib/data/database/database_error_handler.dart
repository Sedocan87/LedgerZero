import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';

class DatabaseErrorHandler {
  static Future<T> execute<T>(Future<T> Function() operation, {String context = 'Database Operation'}) async {
    try {
      return await operation();
    } on SqliteException catch (e) {
      Logger.error('$context failed (SQLite)', e);
      throw DatabaseException('Database error: ${e.message}', e);
    } catch (e, stack) {
      Logger.error('$context failed (Unknown)', e, stack);
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Unexpected database error: $e', e);
    }
  }
}
