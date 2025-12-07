import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late TransactionsDao transactionsDao;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    transactionsDao = TransactionsDao(database);

    // Seed foreign key dependencies
    await database.into(database.accounts).insert(
       AccountsCompanion.insert(
         id: 'acc_1',
         name: 'Test Account',
         type: AccountType.checking.name,
       )
    );

    await database.into(database.categories).insert(
        CategoriesCompanion.insert(
            id: 'cat_1',
            name: 'Test Category',
            createdAt: const Value(null),
        )
    );

    await database.into(database.payees).insert(
        PayeesCompanion.insert(
            id: 'payee_1',
            name: 'Test Payee',
        )
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('Batch insert throughput', () async {
    final stopwatch = Stopwatch()..start();
    const count = 1000;

    final transactions = List.generate(count, (i) {
      return TransactionsCompanion.insert(
        id: const Uuid().v4(),
        accountId: 'acc_1',
        date: DateTime.now(),
        amount: 10.0,
        payeeId: const Value('payee_1'),
        categoryId: const Value('cat_1'),
      );
    });

    await transactionsDao.batchCreateTransactions(transactions);

    stopwatch.stop();
    print('Batch insert of $count transactions took ${stopwatch.elapsedMilliseconds}ms');
  });

  test('Batch update throughput', () async {
    // Setup
    const count = 1000;
    final transactions = List.generate(count, (i) {
      return TransactionsCompanion.insert(
        id: 'tx_$i',
        accountId: 'acc_1',
        date: DateTime.now(),
        amount: 10.0,
      );
    });
    await transactionsDao.batchCreateTransactions(transactions);

    // Measure update
    final stopwatch = Stopwatch()..start();
    final updates = List.generate(count, (i) {
      // Must provide all required fields for replaceAll
      return TransactionsCompanion(
        id: Value('tx_$i'),
        accountId: const Value('acc_1'),
        date: Value(DateTime.now()),
        amount: const Value(20.0),
      );
    });

    await transactionsDao.batchUpdateTransactions(updates);

    stopwatch.stop();
    print('Batch update of $count transactions took ${stopwatch.elapsedMilliseconds}ms');
  });
}
