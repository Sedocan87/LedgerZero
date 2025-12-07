import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/core/constants/app_constants.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class RestoreService {
  final AppDatabase _db;

  RestoreService(this._db);

  /// Restores the database from a backup file.
  ///
  /// [backupFile] can be a `.sqlite` (plaintext) or `.lzbk` (encrypted) file.
  /// If encrypted, [password] must be provided.
  Future<void> restoreBackup(File backupFile, {String? password}) async {
    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(tempDir.path, 'restored_temp_${DateTime.now().millisecondsSinceEpoch}.sqlite');
    File tempDbFile = File(tempDbPath);

    try {
      if (backupFile.path.endsWith('.lzbk')) {
        if (password == null || password.isEmpty) {
          throw const BackupException('Password required for encrypted backup');
        }
        await _decryptBackup(backupFile, tempDbFile, password);
      } else {
        // Assume plaintext sqlite
        await backupFile.copy(tempDbPath);
      }

      // Validate the restored database (Task 597)
      await _validateDatabase(tempDbFile);

      // Replace the current database
      await _replaceDatabase(tempDbFile);

    } catch (e) {
      Logger.error('Restore failed', e);
      rethrow;
    } finally {
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }
    }
  }

  /// Selectively restores transactions from a backup within a date range.
  ///
  /// This merges transactions from the backup into the current database.
  Future<void> selectiveRestore(File backupFile, DateTime start, DateTime end, {String? password}) async {
    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(tempDir.path, 'selective_temp_${DateTime.now().millisecondsSinceEpoch}.sqlite');
    File tempDbFile = File(tempDbPath);

    try {
      // 1. Decrypt/Copy to temp
      if (backupFile.path.endsWith('.lzbk')) {
        if (password == null || password.isEmpty) {
          throw const BackupException('Password required for encrypted backup');
        }
        await _decryptBackup(backupFile, tempDbFile, password);
      } else {
        await backupFile.copy(tempDbPath);
      }

      // 2. Open Temp DB as a Drift Database
      final tempDb = AppDatabase(NativeDatabase(tempDbFile));

      try {
        // 3. Query Transactions in range
        // Note: Drift stores dates as text if configured, or int. Project uses Text.
        final transactionsToImport = await (tempDb.select(tempDb.transactions)
              ..where((t) => t.date.isBetweenValues(start, end)))
            .get();

        Logger.info('Found ${transactionsToImport.length} transactions to merge');

        // 4. Import into Main DB
        // We need to be careful about Payees, Categories, Accounts.
        // Simplified approach: Create missing dependencies if IDs don't exist?
        // Or check by name? ID collision is likely if it's the same DB backup.
        // We assume IDs are UUIDs.

        await _db.transaction(() async {
          for (final tx in transactionsToImport) {
             // Check if transaction exists
             final exists = await (_db.select(_db.transactions)..where((t) => t.id.equals(tx.id))).getSingleOrNull();
             if (exists != null) {
               // Skip or Update? Let's Skip for "Restore".
               continue;
             }

             // Ensure dependencies exist (blind insert might fail FK)
             // We should check Account, Payee, Category.
             // If they don't exist in main DB, we should copy them from temp DB.
             await _ensureDependenciesExist(tempDb, tx);

             // Insert Transaction
             await _db.into(_db.transactions).insert(tx);
          }
        });

      } finally {
        await tempDb.close();
      }

    } catch (e) {
      Logger.error('Selective restore failed', e);
      rethrow;
    } finally {
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }
    }
  }

  Future<void> _ensureDependenciesExist(AppDatabase tempDb, Transaction tx) async {
    // 1. Account
    if (tx.accountId != null) { // accountId is usually not null
       final accountExists = await (_db.select(_db.accounts)..where((a) => a.id.equals(tx.accountId))).getSingleOrNull();
       if (accountExists == null) {
          final account = await (tempDb.select(tempDb.accounts)..where((a) => a.id.equals(tx.accountId))).getSingleOrNull();
          if (account != null) await _db.into(_db.accounts).insert(account);
       }
    }

    // 2. Category
    if (tx.categoryId != null) {
       final catExists = await (_db.select(_db.categories)..where((c) => c.id.equals(tx.categoryId!))).getSingleOrNull();
       if (catExists == null) {
          final cat = await (tempDb.select(tempDb.categories)..where((c) => c.id.equals(tx.categoryId!))).getSingleOrNull();
          if (cat != null) {
            // Also need CategoryGroup!
            if (cat.categoryGroupId != null) {
                final groupExists = await (_db.select(_db.categoryGroups)..where((g) => g.id.equals(cat.categoryGroupId!))).getSingleOrNull();
                if (groupExists == null) {
                   final group = await (tempDb.select(tempDb.categoryGroups)..where((g) => g.id.equals(cat.categoryGroupId!))).getSingleOrNull();
                   if (group != null) await _db.into(_db.categoryGroups).insert(group);
                }
            }
            await _db.into(_db.categories).insert(cat);
          }
       }
    }

    // 3. Payee
    if (tx.payeeId != null) {
       final payeeExists = await (_db.select(_db.payees)..where((p) => p.id.equals(tx.payeeId!))).getSingleOrNull();
       if (payeeExists == null) {
          final payee = await (tempDb.select(tempDb.payees)..where((p) => p.id.equals(tx.payeeId!))).getSingleOrNull();
          if (payee != null) await _db.into(_db.payees).insert(payee);
       }
    }
  }

  Future<void> _decryptBackup(File inputFile, File outputFile, String password) async {
    final inputBytes = await inputFile.readAsBytes();

    // Check minimum length: Salt (32) + IV (12)
    if (inputBytes.length < 44) {
      throw const BackupException('Invalid backup file format');
    }

    final salt = inputBytes.sublist(0, 32);
    final iv = inputBytes.sublist(32, 44);
    final ciphertext = inputBytes.sublist(44);

    final key = _deriveKey(password, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false, // Decrypt
        AEADParameters(
          KeyParameter(key),
          128,
          iv,
          Uint8List(0),
        ),
      );

    try {
      final compressedPlaintext = cipher.process(ciphertext);

      // Decompress (GZIP)
      final plaintext = const GZipDecoder().decodeBytes(compressedPlaintext);

      await outputFile.writeAsBytes(plaintext);
    } catch (e) {
      throw const BackupException('Decryption or decompression failed. Incorrect password?');
    }
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
    final pkcs = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pkcs.init(Pbkdf2Parameters(salt, 100000, 32));
    return pkcs.process(Uint8List.fromList(utf8.encode(password)));
  }

  Future<void> _validateDatabase(File dbFile) async {
    try {
      final db = sqlite.sqlite3.open(dbFile.path);
      try {
        final result = db.select('PRAGMA integrity_check');
        if (result.isEmpty || result.first['integrity_check'] != 'ok') {
          throw const BackupException('Database integrity check failed');
        }

        final tables = db.select("SELECT name FROM sqlite_master WHERE type='table'");
        final tableNames = tables.map((row) => row['name'] as String).toSet();

        const requiredTables = {'accounts', 'transactions', 'categories'};
        if (!requiredTables.every((t) => tableNames.contains(t))) {
          throw const BackupException('Backup is missing required tables');
        }

      } finally {
        db.dispose();
      }
    } catch (e) {
      throw BackupException('Invalid database file: $e');
    }
  }

  Future<void> _replaceDatabase(File newDbFile) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, AppConstants.databaseFilename);
    final dbFile = File(dbPath);

    await _db.close();

    if (await dbFile.exists()) {
      await dbFile.rename('$dbPath.bak');
    }

    await newDbFile.copy(dbPath);

    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}
