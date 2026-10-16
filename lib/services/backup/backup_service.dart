import 'dart:io';

import 'package:intl/intl.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:path/path.dart' as p;

/// Where an encrypted backup can be uploaded.
enum BackupCloudTarget { googleDrive, iCloud }

/// No cloud storage is set up for uploads.
class BackupUploadNotConfiguredException extends BackupException {
  const BackupUploadNotConfiguredException()
    : super('No cloud storage is configured');
}

/// Creates encrypted backups (format v2, see [BackupFormat]).
///
/// Backups are always encrypted with a backup password: there is no
/// plaintext backup. For a readable copy use the JSON/CSV export.
class BackupService {
  final AppDatabase _db;
  final GoogleDriveService? _googleDriveService;
  final ICloudDriveService? _iCloudDriveService;
  final BackupScheduler? _backupScheduler;
  final ExportFileService _files;
  final KdfParams Function() _kdf;

  BackupService(
    this._db, {
    this._googleDriveService,
    this._iCloudDriveService,
    this._backupScheduler,
    ExportFileService? files,
    KdfParams Function()? kdf,
  }) : _files = files ?? ExportFileService(),
       _kdf = kdf ?? KdfParams.recommended;

  /// Writes an encrypted backup into the export directory and records the
  /// backup time. The plaintext snapshot exists only in the app's temporary
  /// directory while the backup is built and is deleted afterwards.
  Future<File> createBackup({required String password}) async {
    if (password.isEmpty) {
      throw const BackupException('A backup password is required');
    }
    final exportDir = await _files.exportDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final snapshot = File(p.join(exportDir.path, '.snapshot_$stamp.sqlite'));
    final output = File(
      p.join(exportDir.path, 'ledgerzero_backup_$stamp.lzbk'),
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
    await _backupScheduler?.recordBackupSuccess();
    return output;
  }

  /// Writes an unencrypted copy of the open database to [target].
  ///
  /// Under SQLCipher `VACUUM INTO` would copy the main database's key, so the
  /// copy is made with `ATTACH ... KEY ''` + `sqlcipher_export`. Plain SQLite
  /// (only possible in tests) falls back to `VACUUM INTO`.
  Future<void> writePlaintextSnapshot(File target) async {
    await _deleteDatabaseFiles(target);
    if (await _db.hasCipherSupport) {
      final version = await _db.customSelect('PRAGMA user_version').getSingle();
      final userVersion = version.data.values.first as int;
      await _db.customStatement("ATTACH DATABASE ? AS lz_export KEY ''", [
        target.path,
      ]);
      try {
        await _db.customSelect("SELECT sqlcipher_export('lz_export')").get();
        await _db.customStatement(
          'PRAGMA lz_export.user_version = $userVersion',
        );
      } finally {
        await _db.customStatement('DETACH DATABASE lz_export');
      }
    } else {
      await _db.customStatement('VACUUM INTO ?', [target.path]);
    }
  }

  /// Uploads [backupFile] to [target]. Errors are not swallowed: a failed
  /// upload throws.
  Future<void> uploadBackupToCloud(
    File backupFile,
    BackupCloudTarget? target,
  ) async {
    final filename = p.basename(backupFile.path);
    switch (target) {
      case BackupCloudTarget.googleDrive:
        final drive = _googleDriveService;
        if (drive == null) {
          throw const BackupUploadNotConfiguredException();
        }
        await drive.uploadBackup(backupFile, filename);
      case BackupCloudTarget.iCloud:
        final iCloud = _iCloudDriveService;
        if (iCloud == null) {
          throw const BackupUploadNotConfiguredException();
        }
        await iCloud.uploadBackup(backupFile, filename);
      case null:
        throw const BackupUploadNotConfiguredException();
    }
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
