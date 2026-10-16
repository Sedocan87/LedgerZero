// TransactionRepositoryImpl on a real in-memory database: entity <-> row
// mapping, soft deletes, account/date queries, streams and error wrapping.
// (Ledger rules on top of it are tested in
// test/domain/services/transaction_service_test.dart.)
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;

  setUp(() async {
    t = TestDatabase();
    await t.addAccount(id: 'a');
    await t.addAccount(id: 'b');
  });
  tearDown(() => t.close());

  Transaction tx(String id, {String account = 'a', int day = 10}) =>
      Transaction(
        id: id,
        accountId: account,
        date: DateTime.utc(2024, 3, day),
        amount: -1234,
        memo: 'memo $id',
        cleared: TransactionClearStatus.cleared,
        approved: true,
      );

  test('every field survives a round trip', () async {
    final groceries = await t.categoryId('Groceries');
    final original = tx('t1').copyWith(categoryId: groceries);
    await t.transactions.createTransaction(original);

    final read = (await t.transactions.getTransactionById('t1'))!;
    expect(read.accountId, 'a');
    expect(read.amount, -1234);
    expect(read.date, DateTime.utc(2024, 3, 10));
    expect(read.date.isUtc, isTrue);
    expect(read.categoryId, groceries);
    expect(read.memo, 'memo t1');
    expect(read.cleared, TransactionClearStatus.cleared);
    expect(read.approved, isTrue);
    expect(read.isDeleted, isFalse);
    expect(read.createdAt, isNotNull);
    expect(read.updatedAt, isNotNull);
  });

  test('updates change the row and bump updatedAt', () async {
    await t.transactions.createTransaction(tx('t1'));
    final before = (await t.transactions.getTransactionById('t1'))!;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await t.transactions.updateTransaction(before.copyWith(amount: 999));
    final after = (await t.transactions.getTransactionById('t1'))!;
    expect(after.amount, 999);
    expect(after.updatedAt!.isAfter(before.updatedAt!), isTrue);
  });

  test('deletes are soft: hidden from reads, kept for sync', () async {
    await t.transactions.createTransaction(tx('t1'));
    await t.transactions.createTransaction(tx('t2'));
    await t.transactions.deleteTransaction('t1');

    expect((await t.transactions.getAllTransactions()).map((x) => x.id), [
      't2',
    ]);
    expect(await t.transactions.getTransactionById('t1'), isNull);
    final kept = await t.transactions.getTransactionByIdIncludingDeleted('t1');
    expect(kept!.isDeleted, isTrue);
  });

  test('by account and by date range (end exclusive)', () async {
    await t.transactions.batchCreateTransactions([
      tx('a1', day: 1),
      tx('a2', day: 15),
      tx('a3', day: 31),
      tx('b1', account: 'b', day: 15),
    ]);
    expect(
      (await t.transactions.getTransactionsByAccount(
        'a',
      )).map((x) => x.id).toSet(),
      {'a1', 'a2', 'a3'},
    );
    final range = await t.transactions.getTransactionsByDateRange(
      DateTime.utc(2024, 3, 1),
      DateTime.utc(2024, 3, 31),
    );
    expect(range.map((x) => x.id).toSet(), {'a1', 'a2', 'b1'});
  });

  test('watchers emit after changes', () async {
    final stream = t.transactions.watchTransactionsByAccount('a');
    final seen = <int>[];
    final sub = stream.listen((rows) => seen.add(rows.length));
    await pumpEventQueue();
    await t.transactions.createTransaction(tx('t1'));
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, 0);
    expect(seen.last, 1);
  });

  test('database errors surface as DatabaseException', () async {
    // Unknown account: the foreign key rejects the row.
    await expectLater(
      t.transactions.createTransaction(tx('t1', account: 'missing')),
      throwsA(isA<DatabaseException>()),
    );
    await t.transactions.createTransaction(tx('t1'));
    // Duplicate primary key.
    await expectLater(
      t.transactions.createTransaction(tx('t1')),
      throwsA(isA<DatabaseException>()),
    );
  });
}
