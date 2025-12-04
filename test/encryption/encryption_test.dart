import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';

void main() {
  if (Platform.isLinux) {
    // Override sqlite3 to use sqlcipher on Linux
    open.overrideFor(OperatingSystem.linux, () {
      final paths = [
        '/usr/lib/x86_64-linux-gnu/libsqlcipher.so',
        '/usr/lib/libsqlcipher.so',
        '/usr/local/lib/libsqlcipher.so',
      ];

      for (final path in paths) {
        if (File(path).existsSync()) {
          return DynamicLibrary.open(path);
        }
      }

      // Fallback to searching LD_LIBRARY_PATH
      return DynamicLibrary.open('libsqlcipher.so');
    });
  }

  group('Database Encryption Tests', () {
    late Directory tempDir;
    late File dbFile;
    const correctKey = 'correct-secret-key-123';
    const wrongKey = 'wrong-key-456';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ledger_zero_encryption_test');
      dbFile = File(p.join(tempDir.path, 'encrypted.db'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<AppDatabase> openDb(String? key) async {
      final db = AppDatabase(NativeDatabase(
        dbFile,
        setup: (rawDb) {
          if (key != null) {
            rawDb.execute("PRAGMA key = '$key'");
          }
        },
      ));
      return db;
    }

    test('Should create an encrypted database and read/write with correct key', () async {
      // 1. Create and write with correct key
      var db = await openDb(correctKey);

      // Add an account
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc1',
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );

      await db.close();

      // 2. Re-open with correct key and verify
      db = await openDb(correctKey);
      final accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
      expect(accounts.first.name, 'Test Account');
      await db.close();
    });

    test('Should fail to read encrypted database without key', () async {
      // 1. Create and write with correct key
      var db = await openDb(correctKey);
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc1',
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );
      await db.close();

      // 2. Try to open without key
      db = await openDb(null);

      try {
        await db.select(db.accounts).get();
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('file is not a database'));
      } finally {
        await db.close();
      }
    });

    test('Should fail to read encrypted database with wrong key', () async {
      // 1. Create and write with correct key
      var db = await openDb(correctKey);
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc1',
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );
      await db.close();

      // 2. Try to open with wrong key
      db = await openDb(wrongKey);

      try {
        await db.select(db.accounts).get();
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('file is not a database'));
      } finally {
        await db.close();
      }
    });

    test('Database file should not have standard SQLite header', () async {
      // 1. Create and write with correct key
      final db = await openDb(correctKey);
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: 'acc1',
          name: 'Test Account',
          type: 'checking',
          createdAt: Value(DateTime.now()),
        ),
      );
      await db.close();

      // 2. Read first 16 bytes of the file
      final bytes = await dbFile.readAsBytes();
      final header = String.fromCharCodes(bytes.take(16));

      // Standard SQLite header is "SQLite format 3\0"
      expect(header, isNot(equals('SQLite format 3\u0000')));
    });
  });
}
