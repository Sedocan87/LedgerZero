import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// What Android's backup and device-to-device transfer copy is
/// `db.sqlite` and `db.sqlite-wal` (android/app/src/main/res/xml/
/// data_extraction_rules.xml). Both copies must be a consistent database.
void main() {
  late Directory tmp;
  late File dbFile;
  late AppDatabase db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('lz_wal_');
    dbFile = File(p.join(tmp.path, 'db.sqlite'));
    db = AppDatabase(NativeDatabase(dbFile));
    for (var i = 0; i < 20; i++) {
      await db.customStatement(
        "INSERT INTO payees (id, name) VALUES ('p$i', 'Payee $i')",
      );
    }
  });

  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  File wal(File f) => File('${f.path}-wal');

  /// Copies the files Android backs up into [name] (like a restore on a
  /// new phone: no -shm) and counts the payees there.
  int restoredPayees(String name, {required bool withWal}) {
    final dir = Directory(p.join(tmp.path, name))..createSync();
    final copy = File(p.join(dir.path, 'db.sqlite'));
    dbFile.copySync(copy.path);
    if (withWal && wal(dbFile).existsSync()) {
      wal(dbFile).copySync(wal(copy).path);
    }
    final restored = sqlite.sqlite3.open(copy.path);
    try {
      return restored.select('SELECT COUNT(*) AS n FROM payees').first['n']
          as int;
    } finally {
      restored.close();
    }
  }

  test('db.sqlite together with its -wal holds every committed row', () {
    expect(wal(dbFile).lengthSync(), greaterThan(0));
    expect(restoredPayees('with_wal', withWal: true), 20);
    // Why the -wal is included: without it recent changes are missing.
    expect(restoredPayees('without_wal', withWal: false), lessThan(20));
  });

  test('after the checkpoint (app in the background) db.sqlite alone holds '
      'everything and the WAL is empty', () async {
    expect(await db.checkpointWal(), isTrue);
    expect(wal(dbFile).lengthSync(), 0);
    expect(restoredPayees('checkpointed', withWal: false), 20);
    expect(restoredPayees('checkpointed_wal', withWal: true), 20);

    // Writing goes on normally afterwards.
    await db.customStatement(
      "INSERT INTO payees (id, name) VALUES ('later', 'Later')",
    );
    expect(restoredPayees('later', withWal: true), 21);
  });
}
