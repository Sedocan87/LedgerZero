import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Database should persist data to file on disk', () async {
    // Create a temporary directory for the database file
    final tempDir = await Directory.systemTemp.createTemp('ledger_zero_test_');
    final dbFile = File(p.join(tempDir.path, 'test_db.sqlite'));

    // Open database
    var database = AppDatabase(NativeDatabase(dbFile));

    // Insert data
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion(
            id: const Value('acc_persistent'),
            name: const Value('Persistent Account'),
            type: const Value('checking'),
            createdAt: Value(DateTime.now()),
          ),
        );

    // Close database
    await database.close();

    // Verify file exists
    expect(await dbFile.exists(), isTrue);

    // Reopen database
    database = AppDatabase(NativeDatabase(dbFile));

    // Verify data exists
    final result = await database.select(database.accounts).get();
    expect(result.length, 1);
    expect(result.first.id, 'acc_persistent');
    expect(result.first.name, 'Persistent Account');

    // Cleanup
    await database.close();
    await tempDir.delete(recursive: true);
  });
}
