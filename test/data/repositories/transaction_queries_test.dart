import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late String account;

  setUp(() async {
    t = TestDatabase();
    account = (await t.addAccount()).id;
  });
  tearDown(() => t.close());

  test('getTransactionById does not return soft-deleted rows', () async {
    await t.addTransaction(
      accountId: account,
      amount: -1,
      id: 'gone',
      isDeleted: true,
    );
    expect(await t.transactions.getTransactionById('gone'), isNull);
    expect(
      await t.transactions.getTransactionByIdIncludingDeleted('gone'),
      isNotNull,
    );
  });

  test('suggested payees ignore soft-deleted transactions', () async {
    final now = DateTime.now().toUtc();
    await t.payees.createPayee(Payee(id: 'p1', name: 'Alpha', createdAt: now));
    await t.payees.createPayee(Payee(id: 'p2', name: 'Beta', createdAt: now));
    // Beta has more transactions, but all of them are deleted.
    for (var i = 0; i < 3; i++) {
      await t.addTransaction(
        accountId: account,
        amount: -1,
        payeeId: 'p2',
        isDeleted: true,
      );
    }
    await t.addTransaction(accountId: account, amount: -1, payeeId: 'p1');
    final suggested = await t.payees.watchSuggestedPayees().first;
    expect(suggested.map((p) => p.name), ['Alpha', 'Beta']);
  });

  group('search', () {
    setUp(() async {
      final now = DateTime.now().toUtc();
      await t.payees.createPayee(
        Payee(id: 'shop', name: 'Corner Shop', createdAt: now),
      );
      await t.addTransaction(
        accountId: account,
        amount: -1234,
        id: 'byPayee',
        payeeId: 'shop',
      );
      await t.addTransaction(
        accountId: account,
        amount: -500,
        id: 'byCategory',
        categoryId: await t.categoryId('Groceries'),
      );
      await t.addTransaction(accountId: account, amount: 9900, id: 'byAmount');
      await t.db.customStatement(
        "UPDATE transactions SET memo = '100% fun_stuff' WHERE id = 'byAmount'",
      );
    });

    Future<Set<String>> search(String? text, {int? amount}) async {
      final rows = await t.transactions.getTransactions(
        filter: TransactionFilter(searchText: text, searchAmount: amount),
      );
      return rows.map((r) => r.id).toSet();
    }

    test('matches payee name, category name and memo', () async {
      expect(await search('corner'), {'byPayee'});
      expect(await search('grocer'), {'byCategory'});
      expect(await search('FUN'), {'byAmount'});
    });

    test('LIKE wildcards in the query are literal', () async {
      expect(await search('100%'), {'byAmount'});
      expect(await search('f_n'), isEmpty);
      expect(await search('fun_s'), {'byAmount'});
    });

    test('matches the absolute amount', () async {
      expect(await search('12.34', amount: 1234), {'byPayee'});
      expect(await search(null, amount: 9900), {'byAmount'});
    });

    test('payee and absolute amount filters', () async {
      final byPayee = await t.transactions.getTransactions(
        filter: const TransactionFilter(payeeIds: ['shop']),
      );
      expect(byPayee.map((r) => r.id), ['byPayee']);
      final range = await t.transactions.getTransactions(
        filter: const TransactionFilter(minAbsAmount: 1000, maxAbsAmount: 5000),
      );
      expect(range.map((r) => r.id), ['byPayee']);
    });
  });

  group('search finds splits through their lines (L8)', () {
    setUp(() async {
      await t.addTransaction(accountId: account, amount: -3000, id: 'split');
      await t.addTransaction(
        accountId: account,
        amount: -2000,
        id: 'line1',
        parentTransactionId: 'split',
        categoryId: await t.categoryId('Groceries'),
      );
      await t.addTransaction(
        accountId: account,
        amount: -1000,
        id: 'line2',
        parentTransactionId: 'split',
      );
      await t.db.customStatement(
        "UPDATE transactions SET memo = 'bananas' WHERE id = 'line2'",
      );
      await t.addTransaction(
        accountId: account,
        amount: -700,
        id: 'gone-line',
        parentTransactionId: 'split',
        isDeleted: true,
      );
      await t.db.customStatement(
        "UPDATE transactions SET memo = 'deleted apples' WHERE id = 'gone-line'",
      );
    });

    Future<Set<String>> listSearch(String? text, {int? amount}) async {
      final rows = await t.transactions.getTransactions(
        filter: TransactionFilter(
          searchText: text,
          searchAmount: amount,
          excludeSplitChildren: true,
        ),
      );
      return rows.map((r) => r.id).toSet();
    }

    test('a line memo, category or amount matches the parent', () async {
      expect(await listSearch('bananas'), {'split'});
      expect(await listSearch('grocer'), {'split'});
      expect(await listSearch('20.00', amount: 2000), {'split'});
    });

    test('a deleted line does not match', () async {
      expect(await listSearch('apples'), isEmpty);
    });

    test('lines themselves stay hidden from the list', () async {
      final rows = await t.transactions.getTransactions(
        filter: const TransactionFilter(excludeSplitChildren: true),
      );
      expect(rows.map((r) => r.id), ['split']);
    });
  });
}
