import 'dart:io';

import 'package:intl/intl.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:path/path.dart' as p;

/// Creates encrypted backups (format v2, see [BackupFormat]).
///
/// Backups are always encrypted with a backup password: there is no
/// plaintext backup. For a readable copy use the JSON/CSV export.
class BackupService {
  final AppDatabase _db;
  final BackupScheduler? _backupScheduler;
  final ExportFileService _files;
  final KdfParams Function() _kdf;

  BackupService(
    this._db, {
    this._backupScheduler,
    ExportFileService? files,
    KdfParams Function()? kdf,
  }) : _files = files ?? ExportFileService(),
       _kdf = kdf ?? KdfParams.recommended;

  /// Writes an encrypted backup into the export directory, or into
  /// [directory] as [filename] (automatic backups). The plaintext snapshot
  /// exists only in the app's temporary directory while the backup is
  /// built and is deleted afterwards. The backup time is recorded by
  /// [recordBackupCompleted] once the file actually left the phone.
  Future<File> createBackup({
    required String password,
    Directory? directory,
    String? filename,
  }) async {
    if (password.isEmpty) {
      throw const BackupException('A backup password is required');
    }
    final exportDir = await _files.exportDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final snapshot = File(p.join(exportDir.path, '.snapshot_$stamp.sqlite'));
    final output = File(
      p.join(
        (directory ?? exportDir).path,
        p.basename(filename ?? 'ledgerzero_backup_$stamp.lzbk'),
      ),
    );
    try {
      await writePlaintextSnapshot(snapshot);
      await BackupFormat.encryptFile(
        plaintext: snapshot,
        output: output,
        password: password,
        schemaVersion: _db.schemaVersion,
        kdf: _kdf(),
      );
    } catch (_) {
      await _deleteIfExists(output);
      rethrow;
    } finally {
      await _deleteDatabaseFiles(snapshot);
    }
    return output;
  }

  /// Records now as the last backup time (for the backup reminder). Call
  /// it after the share sheet handed the file on or the file was saved
  /// through the system file picker ("Save to…"), not when the file was
  /// merely written: a cancelled share sheet or picker must not silence the
  /// reminder. The automatic backups on the phone never call it.
  Future<void> recordBackupCompleted() async {
    await _backupScheduler?.recordBackupSuccess();
  }

  /// Writes a consistent copy of the open database to [target] with
  /// `VACUUM INTO` (the schema version, `user_version`, is copied too).
  Future<void> writePlaintextSnapshot(File target) async {
    await _deleteDatabaseFiles(target);
    await _db.customStatement('VACUUM INTO ?', [target.path]);
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<void> _deleteDatabaseFiles(File file) async {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      await _deleteIfExists(File('${file.path}$suffix'));
    }
  }
}
