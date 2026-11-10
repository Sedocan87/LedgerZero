import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = Directory.systemTemp.createTempSync('lz_conn_');
    file = File('${dir.path}/db.sqlite');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> writeAccount() async {
    final db = AppDatabase(openConnection(file: file));
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'acc-1',
            name: 'Savings Account',
            type: 'savings',
          ),
        );
    await db.close();
  }

  /// A database file at schema [version] (tables of the current schema).
  void writeSchemaVersion(int version) {
    final db = sqlite.sqlite3.open(file.path);
    try {
      db.execute('PRAGMA user_version = $version');
    } finally {
      db.close();
    }
  }

  test('creates a plain SQLite file that reopens', () async {
    await writeAccount();

    final bytes = file.readAsBytesSync();
    expect(ascii.decode(bytes.sublist(0, 15)), 'SQLite format 3');

    final db = AppDatabase(openConnection(file: file));
    final accounts = await db.select(db.accounts).get();
    expect(accounts.single.name, 'Savings Account');
    await db.close();
  });

  group('checkDatabaseFile', () {
    test('no file yet', () async {
      expect(await checkDatabaseFile(file), DatabaseFileState.missing);
    });

    test('a database of this version', () async {
      await writeAccount();
      expect(await checkDatabaseFile(file), DatabaseFileState.usable);
    });

    test('an empty file is set up like a new one', () async {
      file.writeAsBytesSync(const []);
      expect(await checkDatabaseFile(file), DatabaseFileState.usable);
    });

    test('a file that is not a database is damaged', () async {
      file.writeAsBytesSync(List.filled(4096, 7));
      expect(await checkDatabaseFile(file), DatabaseFileState.damaged);
    });

    test('a database older than v${AppDatabase.minimumSchemaVersion} is too '
        'old', () async {
      await writeAccount();
      writeSchemaVersion(AppDatabase.minimumSchemaVersion - 1);
      expect(await checkDatabaseFile(file), DatabaseFileState.tooOld);
    });

    test('an interrupted restore is finished first', () async {
      await writeAccount();
      final files = RestoreFiles(file);
      // Killed between moving the live file aside and renaming the new one.
      await files.marker.writeAsString('1');
      await moveDatabaseFileSet(file, files.staged);
      expect(await checkDatabaseFile(file), DatabaseFileState.usable);
      expect(await files.marker.exists(), isFalse);
      expect(await files.staged.exists(), isFalse);
    });
  });
}
