import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:archive/archive.dart';

class BackupService {
  final AppDatabase _db;
  final GoogleDriveService? _googleDriveService;
  final ICloudDriveService? _iCloudDriveService;
  final BackupScheduler? _backupScheduler;

  BackupService(
    this._db, {
    GoogleDriveService? googleDriveService,
    ICloudDriveService? iCloudDriveService,
    BackupScheduler? backupScheduler,
  })  : _googleDriveService = googleDriveService,
        _iCloudDriveService = iCloudDriveService,
        _backupScheduler = backupScheduler;

  /// Creates a backup of the current database.
  ///
  /// If [password] is provided, the backup file will be encrypted using AES-GCM.
  /// The resulting file will have extension `.lzbk` if encrypted, or `.sqlite` if plain.
  ///
  /// Returns the path to the backup file.
  Future<File> createBackup({String? password}) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDbName = 'backup_temp_$timestamp.sqlite';
    final tempDbPath = p.join(tempDir.path, tempDbName);

    // Ensure previous file doesn't exist
    final tempDbFile = File(tempDbPath);
    if (await tempDbFile.exists()) {
      await tempDbFile.delete();
    }

    // 1. Create a plaintext snapshot of the database using VACUUM INTO
    await _db.customStatement('VACUUM INTO ?', [tempDbPath]);

    if (password == null || password.isEmpty) {
      // Return the plaintext backup (renamed to avoid confusion with temp)
      final finalPath = p.join(tempDir.path, 'backup_$timestamp.sqlite');
      return await tempDbFile.rename(finalPath);
    }

    // 2. Encrypt the backup
    try {
      final file = await _encryptBackup(tempDbFile, password, timestamp);
      await _backupScheduler?.recordBackupSuccess();
      return file;
    } finally {
      // Clean up the temporary plaintext file
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }
    }
  }

  Future<void> uploadBackupToCloud(File backupFile) async {
    final filename = p.basename(backupFile.path);

    // Try Google Drive first
    if (_googleDriveService != null) {
      // We don't check sync status per se, assuming if the service is injected/available, we try.
      // But typically we should check if enabled.
      // For now, we attempt if the service is non-null, catching errors.
      try {
        await _googleDriveService.uploadBackup(backupFile, filename);
      } catch (e) {
        // Log or rethrow depending on if we want partial success
        // Assuming we want to try both if possible, or just one.
        // In reality, only one sync provider is usually active.
      }
    }

    // Try iCloud
    if (_iCloudDriveService != null) {
      try {
        await _iCloudDriveService.uploadBackup(backupFile, filename);
      } catch (e) {
         // handle error
      }
    }
  }

  Future<File> _encryptBackup(File inputFile, String password, int timestamp) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(tempDir.path, 'backup_$timestamp.lzbk');

    // 1. Generate Salt (32 bytes)
    final salt = _generateRandomBytes(32);

    // 2. Generate IV (12 bytes for GCM)
    final iv = _generateRandomBytes(12);

    // 3. Derive Key using PBKDF2
    final key = _deriveKey(password, salt);

    // 4. Initialize AES-GCM Cipher
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true, // Encrypt
        AEADParameters(
          KeyParameter(key),
          128, // Mac size (128 bits)
          iv,
          Uint8List(0), // No Associated Data
        ),
      );

    // 5. Read input file
    final inputBytes = await inputFile.readAsBytes();

    // 5a. Compress (GZIP)
    // Compression before encryption is crucial for size reduction
    final compressedBytes = const GZipEncoder().encode(inputBytes);

    // 6. Encrypt
    final encryptedBytes = cipher.process(Uint8List.fromList(compressedBytes));

    // 7. Write Output: [Salt (32)] [IV (12)] [Encrypted Data]
    final outputFile = File(outputPath);
    final sink = outputFile.openWrite();
    sink.add(salt);
    sink.add(iv);
    sink.add(encryptedBytes);
    await sink.flush();
    await sink.close();

    return outputFile;
  }

  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pkcs.init(Pbkdf2Parameters(salt, 100000, 32)); // 100k iterations, 32 byte key
    return pkcs.process(Uint8List.fromList(utf8.encode(password)));
  }
}
