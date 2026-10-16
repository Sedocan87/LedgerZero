import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/backup/restore_service.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:path_provider/path_provider.dart';

/// On-device check of the encrypted backup/restore path with the SQLCipher
/// build that ships in the app (Android/iOS), using the real temp and
/// documents directories of the device.
class _Lifecycle implements DatabaseLifecycle {
  final File file;
  final Uint8List key;
  AppDatabase? db;
  _Lifecycle(this.file, this.key);

  AppDatabase open() =>
      db = AppDatabase(openEncryptedConnection(key, file: file));

  @override
  Future<void> close() async {
    await db?.close();
    db = null;
  }

  @override
  Future<AppDatabase> reopen() async => open();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('encrypted backup restores into a keyed database on device', (
    tester,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final work = Directory(
      '${docs.path}/it_backup_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final liveFile = File('${work.path}/ledger_zero.db');
    final key = secureRandomBytes(32);
    final lifecycle = _Lifecycle(liveFile, key);
    final files = ExportFileService(deferDeletion: false);
    KdfParams fast() => KdfParams.argon2id(memoryKiB: 1024, iterations: 1);

    try {
      final db = lifecycle.open();
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc_backup_test',
              name: 'Backup Test Account',
              type: 'checking',
            ),
          );

      final backup = await BackupService(
        db,
        files: files,
        kdf: fast,
      ).createBackup(password: 'integration test password');
      expect(
        latin1.decode(backup.readAsBytesSync()).contains('Backup Test Account'),
        isFalse,
      );

      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'later',
              name: 'Later',
              type: 'checking',
            ),
          );

      await RestoreService(
        () => lifecycle.db!,
        lifecycle: lifecycle,
        databaseFile: () async => liveFile,
        dataKey: () => key,
      ).restoreBackup(backup, password: 'integration test password');

      final restored = lifecycle.db!;
      final accounts = await restored.select(restored.accounts).get();
      expect(accounts.map((a) => a.id), ['acc_backup_test']);
      await lifecycle.close();
      expect(SqlCipher.canOpen(liveFile, RawSqlCipherKey(key)), isTrue);
      await backup.delete();
    } finally {
      await lifecycle.close();
      work.deleteSync(recursive: true);
    }
  });
}
