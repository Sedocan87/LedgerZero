import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/repositories/account_repository_impl.dart';
import '../fixtures/model_factories.dart';

void main() {
  late AppDatabase database;
  late AccountsDao accountsDao;
  late AccountRepositoryImpl accountRepository;

  setUp(() {
    // Use in-memory database for benchmarks to test logic/mapping overhead
    // without disk I/O noise (though SQLite memory is still "database" speed)
    database = AppDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(database);
    accountRepository = AccountRepositoryImpl(accountsDao);
  });

  tearDown(() async {
    await database.close();
  });

  test('Benchmark: Insert 1000 Accounts', () async {
    final stopwatch = Stopwatch()..start();

    // We intentionally do this in a loop to test repository overhead per call.
    // In real app, we would batch, but we want to measure the repo method cost.
    for (int i = 0; i < 1000; i++) {
      final account = createTestAccount(
        id: 'acc_$i',
        name: 'Account $i',
      );
      await accountRepository.createAccount(account);
    }

    stopwatch.stop();
    // ignore: avoid_print
    // print('Benchmark - Insert 1000 Accounts: ${stopwatch.elapsedMilliseconds}ms');

    // Expect reasonable performance (avg < 2ms per insert including overhead)
    // 1000 items in < 2000ms
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });

  test('Benchmark: Read 1000 Accounts', () async {
    // Seed
    for (int i = 0; i < 1000; i++) {
      final account = createTestAccount(
        id: 'acc_$i',
        name: 'Account $i',
      );
      await accountRepository.createAccount(account);
    }

    final stopwatch = Stopwatch()..start();
    final accounts = await accountRepository.getAllAccounts();
    stopwatch.stop();

    // ignore: avoid_print
    // print('Benchmark - Read 1000 Accounts: ${stopwatch.elapsedMilliseconds}ms');

    expect(accounts.length, 1000);
    // Read should be fast
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test('Benchmark: Update 1000 Accounts', () async {
    // Seed
     for (int i = 0; i < 1000; i++) {
      final account = createTestAccount(
        id: 'acc_$i',
        name: 'Account $i',
      );
      await accountRepository.createAccount(account);
    }

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < 1000; i++) {
      final account = createTestAccount(
        id: 'acc_$i',
        name: 'Updated Account $i',
        currentBalance: 100.0,
      );
      await accountRepository.updateAccount(account);
    }

    stopwatch.stop();
    // ignore: avoid_print
    // print('Benchmark - Update 1000 Accounts: ${stopwatch.elapsedMilliseconds}ms');

    expect(stopwatch.elapsedMilliseconds, lessThan(3000)); // Updates can be slightly slower
  });
}
