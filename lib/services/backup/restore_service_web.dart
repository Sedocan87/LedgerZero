import 'package:ledger_zero/core/platform/io.dart';
import 'package:ledger_zero/data/database/database.dart';

class RestoreService {
  // ignore: unused_field - Required for API compatibility with native RestoreService
  final AppDatabase _db;

  RestoreService(this._db);

  Future<void> restoreBackup(File backupFile, {String? password}) async {
    throw UnimplementedError('Restore not supported on web');
  }

  Future<void> selectiveRestore(
    File backupFile,
    DateTime start,
    DateTime end, {
    String? password,
  }) async {
    throw UnimplementedError('Restore not supported on web');
  }

  Future<List<int>> createBackup({String? password}) async {
    throw UnimplementedError('Backup not supported on web');
  }

  Future<File> createBackupFile({String? password}) async {
    throw UnimplementedError('Backup not supported on web');
  }

  Future<void> uploadBackupToCloud(File file) async {
    throw UnimplementedError('Cloud backup not supported on web');
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}
