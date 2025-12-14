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
      return DynamicLibrary.open('libsqlcipher.so');
    });
  }

  group('Encryption Performance Benchmarks', () {
    late Directory tempDir;
    late File encryptedFile;
    late File plainFile;
    const key = 'benchmark-key-123';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ledger_zero_bench_test');
      encryptedFile = File(p.join(tempDir.path, 'encrypted.db'));
      plainFile = File(p.join(tempDir.path, 'plain.db'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<AppDatabase> openDb(File file, String? key) async {
      return AppDatabase(
        NativeDatabase(
          file,
          setup: (rawDb) {
            if (key != null) {
              rawDb.execute("PRAGMA key = '$key'");
            }
          },
        ),
      );
    }

    Future<void> runBenchmark(String label, File file, String? key) async {
      final db = await openDb(file, key);
      final stopwatch = Stopwatch()..start();

      // Batch Insert
      const count = 1000;
      await db.batch((batch) {
        for (var i = 0; i < count; i++) {
          batch.insert(
            db.accounts,
            AccountsCompanion.insert(
              id: 'acc_$i',
              name: 'Account $i',
              type: 'checking',
              createdAt: Value(DateTime.now()),
            ),
          );
        }
      });
      // final insertTime = stopwatch.elapsedMilliseconds;
      stopwatch.reset();

      // Read
      final accounts = await db.select(db.accounts).get();
      // final readTime = stopwatch.elapsedMilliseconds;

      expect(accounts.length, count);

      // Avoid print in production code but useful here
      // ignore: avoid_print
      // print('$label - Insert (1000): ${insertTime}ms, Read (1000): ${readTime}ms');
      await db.close();
    }

    test('Benchmark Plain vs Encrypted', () async {
      // ignore: avoid_print
      // print('--- Benchmark Results ---');
      await runBenchmark('Plain    ', plainFile, null);
      await runBenchmark('Encrypted', encryptedFile, key);
      // ignore: avoid_print
      // print('-------------------------');
    });
  });
}
