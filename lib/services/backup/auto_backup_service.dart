import 'dart:io';

import 'package:intl/intl.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/security/secure_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

/// Automatic backups are on but no backup password is stored (the secure
/// storage lost it): the user has to turn them on again.
class AutoBackupNotConfiguredException implements Exception {
  const AutoBackupNotConfiguredException();
  @override
  String toString() => 'AutoBackupNotConfiguredException';
}

/// An automatic backup file on this phone.
class AutoBackupFile {
  const AutoBackupFile(this.file, this.createdAt, this.sizeBytes);
  final File file;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Writes an encrypted backup on this phone once a day, without the user
/// doing anything.
///
/// The backups use the backup password the user chose when turning the
/// feature on (kept in [SecureStore]) and the normal backup format, so they
/// restore like a manual backup. They live in [directory], outside the
/// export directory and outside what a factory reset deletes: when the
/// Android KeyStore loses the database key, the data on the phone is gone,
/// but these files are still there and open with the password. They do not
/// survive a lost phone, a factory reset of the phone or an uninstall; the
/// Backup screen tells the user to copy the folder away now and then.
///
/// The last [keep] backups are kept, older ones are deleted. A run happens
/// when the app starts or resumes and the last successful backup is older
/// than [interval]; after a failure the next try waits [retryAfter].
class AutoBackupService {
  AutoBackupService(
    this._prefs,
    this._store, {
    required this.backupService,
    required this.baseDirectory,
    DateTime Function()? now,
    this.interval = const Duration(hours: 24),
    this.retryAfter = const Duration(hours: 1),
    this.keep = 7,
  }) : _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final SecureStore _store;

  /// The backup service of the open database (read per run: a restore
  /// opens a new connection).
  final BackupService Function() backupService;

  /// Where [directoryName] is created: the app's external files directory
  /// on Android (visible over USB and in file managers), else the app
  /// documents directory.
  final Future<Directory> Function() baseDirectory;
  final DateTime Function() _now;
  final Duration interval;
  final Duration retryAfter;
  final int keep;
  final _lock = Lock();

  static const String enabledKey = 'auto_backup_enabled';
  static const String lastSuccessKey = 'auto_backup_last_success';
  static const String lastAttemptKey = 'auto_backup_last_attempt';
  static const String lastErrorKey = 'auto_backup_last_error';
  static const String passwordKey = 'lz_auto_backup_password_v1';
  static const String directoryName = 'backups';
  static const String filePrefix = 'ledgerzero_auto_';
  static const String fileExtension = '.lzbk';

  bool get isEnabled => _prefs.getBool(enabledKey) ?? false;

  DateTime? get lastSuccess => _time(lastSuccessKey);

  DateTime? get lastAttempt => _time(lastAttemptKey);

  /// What the last failed run reported, until a run succeeds.
  String? get lastError => _prefs.getString(lastErrorKey);

  DateTime? _time(String key) {
    final ms = _prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// The folder holding the automatic backups (created when missing).
  Future<Directory> directory() async {
    final base = await baseDirectory();
    final dir = Directory(p.join(base.path, directoryName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Turns automatic backups on with [password] and makes the first one
  /// right away. Throws when that first backup fails; the feature stays on
  /// and the next start retries.
  Future<File> enable(String password) async {
    if (password.isEmpty) {
      throw const BackupException('A backup password is required');
    }
    await _store.write(passwordKey, password);
    await _prefs.setBool(enabledKey, true);
    await _prefs.remove(lastErrorKey);
    return runNow();
  }

  /// Replaces the password used from the next backup on.
  Future<void> changePassword(String password) async {
    if (password.isEmpty) {
      throw const BackupException('A backup password is required');
    }
    await _store.write(passwordKey, password);
  }

  /// Turns automatic backups off. The files stay (see [deleteAll]).
  Future<void> disable() async {
    await _prefs.setBool(enabledKey, false);
    await _prefs.remove(lastErrorKey);
    await _store.delete(passwordKey);
  }

  /// Forgets the stored password (factory reset).
  Future<void> forgetPassword() => _store.delete(passwordKey);

  /// Whether a run is due now: on, and the last success is older than
  /// [interval] (or there is none), and the last try is older than
  /// [retryAfter].
  bool get isDue {
    if (!isEnabled) {
      return false;
    }
    final now = _now();
    final success = lastSuccess;
    if (success != null && now.difference(success) < interval) {
      return false;
    }
    final attempt = lastAttempt;
    if (attempt != null && now.difference(attempt) < retryAfter) {
      return false;
    }
    return true;
  }

  /// Makes a backup when one is due. Failures are recorded and logged, not
  /// thrown: this runs unattended at start-up and on resume.
  Future<File?> runIfDue() async {
    if (!isDue) {
      return null;
    }
    try {
      return await runNow();
    } catch (_) {
      // Recorded by runNow; a closed database (restore, factory reset)
      // is retried at the next start.
      return null;
    }
  }

  /// Makes a backup now and rotates the folder. Throws on failure, after
  /// recording it for the Backup screen.
  Future<File> runNow() => _lock.synchronized(() async {
    final now = _now();
    await _prefs.setInt(lastAttemptKey, now.millisecondsSinceEpoch);
    try {
      final password = await _store.read(passwordKey);
      if (password == null || password.isEmpty) {
        throw const AutoBackupNotConfiguredException();
      }
      final dir = await directory();
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
      final service = backupService();
      final file = await service.createBackup(
        password: password,
        directory: dir,
        filename: '$filePrefix$stamp$fileExtension',
      );
      await _rotate(dir, keepFile: file);
      await _prefs.setInt(lastSuccessKey, now.millisecondsSinceEpoch);
      await _prefs.remove(lastErrorKey);
      await service.recordBackupCompleted();
      Logger.info('Automatic backup written: ${p.basename(file.path)}');
      return file;
    } catch (e, stackTrace) {
      await _prefs.setString(lastErrorKey, _describe(e));
      Logger.warning('Automatic backup failed', e, stackTrace);
      rethrow;
    }
  });

  /// The automatic backups on this phone, newest first.
  Future<List<AutoBackupFile>> listBackups() async {
    final dir = await directory();
    final files = <AutoBackupFile>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !_isAutoBackup(entry)) {
        continue;
      }
      final stat = await entry.stat();
      files.add(
        AutoBackupFile(entry, _stampOf(entry) ?? stat.modified, stat.size),
      );
    }
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }

  /// Deletes every automatic backup on this phone.
  Future<void> deleteAll() async {
    for (final backup in await listBackups()) {
      await backup.file.delete();
    }
  }

  /// Keeps the newest [keep] backups (and [keepFile] whatever its time).
  Future<void> _rotate(Directory dir, {required File keepFile}) async {
    final backups = await listBackups();
    final keepPath = p.normalize(keepFile.path);
    var kept = 0;
    for (final backup in backups) {
      final isNew = p.normalize(backup.file.path) == keepPath;
      if (isNew || kept < keep) {
        kept++;
        continue;
      }
      try {
        await backup.file.delete();
      } catch (e) {
        Logger.warning('Could not delete an old automatic backup', e);
      }
    }
  }

  /// The time in the file name (the clock of the run that wrote it).
  static DateTime? _stampOf(File file) {
    final name = p.basename(file.path);
    final stamp = name.substring(
      filePrefix.length,
      name.length - fileExtension.length,
    );
    final m = _stampPattern.firstMatch(stamp);
    if (m == null) {
      return null;
    }
    final n = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    return DateTime(n[0], n[1], n[2], n[3], n[4], n[5]);
  }

  static final RegExp _stampPattern = RegExp(
    r'^(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})$',
  );

  static bool _isAutoBackup(File file) {
    final name = p.basename(file.path);
    return name.startsWith(filePrefix) && name.endsWith(fileExtension);
  }

  static String _describe(Object error) {
    final text = error.toString();
    return text.length > 200 ? text.substring(0, 200) : text;
  }
}
