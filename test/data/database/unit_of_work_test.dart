import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  test('a failing unit of work rolls back every write', () async {
    final account = await t.addAccount();
    await expectLater(
      t.unitOfWork.run(() async {
        await t.addTransaction(accountId: account.id, amount: -100, id: 'a');
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(await t.transactions.getTransactionById('a'), isNull);
  });

  test(
    'repositories that open their own transaction nest as savepoints',
    () async {
      final account = await t.addAccount();
      final other = await t.addAccount(name: 'Other');
      await expectLater(
        t.unitOfWork.run(() async {
          // createTransferTransaction opens a nested drift transaction.
          await t.transactions.createTransferTransaction(
            (await t.addTransaction(
              accountId: account.id,
              amount: -1,
              id: 'x',
            )).copyWith(id: 'leg1'),
            (await t.addTransaction(
              accountId: other.id,
              amount: 1,
              id: 'y',
            )).copyWith(id: 'leg2'),
          );
          throw StateError('outer fails after the inner commit');
        }),
        throwsStateError,
      );
      for (final id in ['x', 'y', 'leg1', 'leg2']) {
        expect(await t.transactions.getTransactionById(id), isNull, reason: id);
      }
    },
  );

  test('nested units of work commit with the outer one', () async {
    final account = await t.addAccount();
    await t.unitOfWork.run(() async {
      await t.unitOfWork.run(
        () => t.addTransaction(accountId: account.id, amount: -1, id: 'n'),
      );
    });
    expect(await t.transactions.getTransactionById('n'), isNotNull);
  });
}
