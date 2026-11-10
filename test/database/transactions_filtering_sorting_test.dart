import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/transaction.dart' as domain;
import 'package:ledger_zero/domain/entities/transaction_filter.dart';

void main() {
  late AppDatabase database;
  late TransactionsDao transactionsDao;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    transactionsDao = TransactionsDao(database);

    // Setup data
    await database
        .into(database.accounts)
        .insert(
          const AccountsCompanion(
            id: Value('acc1'),
            name: Value('Checking'),
            type: Value('checking'),
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          const AccountsCompanion(
            id: Value('acc2'),
            name: Value('Savings'),
            type: Value('savings'),
          ),
        );

    await database
        .into(database.payees)
        .insert(const PayeesCompanion(id: Value('p1'), name: Value('Walmart')));
    await database
        .into(database.payees)
        .insert(const PayeesCompanion(id: Value('p2'), name: Value('Amazon')));

    await database
        .into(database.categories)
        .insert(
          const CategoriesCompanion(id: Value('c1'), name: Value('Groceries')),
        );
    await database
        .into(database.categories)
        .insert(
          const CategoriesCompanion(id: Value('c2'), name: Value('Shopping')),
        );

    // Insert Transactions
    await transactionsDao.insertTransaction(
      TransactionsCompanion(
        id: const Value('t1'),
        accountId: const Value('acc1'),
        date: Value(DateTime(2025, 1, 10)),
        amount: const Value(-5000),
        payeeId: const Value('p1'), // Walmart
        categoryId: const Value('c1'), // Groceries
        cleared: const Value(1), // cleared
        memo: const Value('Weekly groceries'),
      ),
    );

    await transactionsDao.insertTransaction(
      TransactionsCompanion(
        id: const Value('t2'),
        accountId: const Value('acc1'),
        date: Value(DateTime(2025, 1, 12)),
        amount: const Value(-10000),
        payeeId: const Value('p2'), // Amazon
        categoryId: const Value('c2'), // Shopping
        cleared: const Value(0), // uncleared
      ),
    );

    await transactionsDao.insertTransaction(
      TransactionsCompanion(
        id: const Value('t3'),
        accountId: const Value('acc2'),
        date: Value(DateTime(2025, 1, 15)),
        amount: const Value(100000), // Income
        cleared: const Value(1), // cleared
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('TransactionsDao Filtering', () {
    test('filter by account', () async {
      const filter = TransactionFilter(accountIds: ['acc1']);
      final results = await transactionsDao.getTransactions(filter: filter);
      expect(results.length, 2);
      expect(results.any((t) => t.id == 't3'), isFalse);
    });

    test('filter by date range', () async {
      final filter = TransactionFilter(
        startDate: DateTime(2025, 1, 11),
        endDate: DateTime(2025, 1, 13),
      );
      final results = await transactionsDao.getTransactions(filter: filter);
      expect(results.length, 1);
      expect(results.first.id, 't2');
    });

    test('filter by amount', () async {
      const filter = TransactionFilter(minAmount: -6000, maxAmount: -4000);
      final results = await transactionsDao.getTransactions(filter: filter);
      expect(results.length, 1);
      expect(results.first.id, 't1');
    });

    test('filter by payee', () async {
      const filter = TransactionFilter(payeeIds: ['p2']); // Amazon
      final results = await transactionsDao.getTransactions(filter: filter);
      expect(results.length, 1);
      expect(results.first.id, 't2');
    });

    test('filter by category', () async {
      const filter = TransactionFilter(categoryIds: ['c1']); // Groceries
      final results = await transactionsDao.getTransactions(filter: filter);
      expect(results.length, 1);
      expect(results.first.id, 't1');
    });

    test('filter by memo', () async {
      const filter = TransactionFilter(memoSearch: 'groceries');
      final results = await transactionsDao.getTransactions(filter: filter);
      expect(results.length, 1);
      expect(results.first.id, 't1');
    });

    test('filter by cleared status', () async {
      const filter = TransactionFilter(
        clearedStatuses: [domain.TransactionClearStatus.uncleared],
      );
      final results = await transactionsDao.getTransactions(filter: filter);
      expect(results.length, 1);
      expect(results.first.id, 't2');
    });
  });

  group('TransactionsDao Sorting', () {
    test('sort by date desc (default)', () async {
      final results = await transactionsDao.getTransactions();
      expect(results.length, 3);
      expect(results[0].id, 't3'); // 15th
      expect(results[1].id, 't2'); // 12th
      expect(results[2].id, 't1'); // 10th
    });

    test('sort by date asc', () async {
      const sort = TransactionSort(
        field: TransactionSortField.date,
        ascending: true,
      );
      final results = await transactionsDao.getTransactions(sort: sort);
      expect(results[0].id, 't1');
      expect(results[1].id, 't2');
      expect(results[2].id, 't3');
    });

    test('sort by amount asc', () async {
      const sort = TransactionSort(
        field: TransactionSortField.amount,
        ascending: true,
      );
      final results = await transactionsDao.getTransactions(sort: sort);
      // -100, -50, 1000
      expect(results[0].id, 't2');
      expect(results[1].id, 't1');
      expect(results[2].id, 't3');
    });

    test('sort by payee name asc', () async {
      // Amazon (p2), Walmart (p1), null
      const sort = TransactionSort(
        field: TransactionSortField.payeeName,
        ascending: true,
      );
      // "Amazon" < "Walmart"; t3 (other account) is filtered out.
      const filter = TransactionFilter(accountIds: ['acc1']);
      final resultsFiltered = await transactionsDao.getTransactions(
        filter: filter,
        sort: sort,
      );

      expect(resultsFiltered[0].id, 't2'); // Amazon
      expect(resultsFiltered[1].id, 't1'); // Walmart
    });

    test('sort by category name asc', () async {
      // Groceries (c1), Shopping (c2)
      const sort = TransactionSort(
        field: TransactionSortField.categoryName,
        ascending: true,
      );
      const filter = TransactionFilter(accountIds: ['acc1']);
      final results = await transactionsDao.getTransactions(
        filter: filter,
        sort: sort,
      );

      expect(results[0].id, 't1'); // Groceries
      expect(results[1].id, 't2'); // Shopping
    });

    group('a stable order within a day (ledger improvement 2)', () {
      // Same day, inserted in this order; created_at says which was
      // entered first, the id breaks a remaining tie.
      setUp(() async {
        final day = DateTime.utc(2025, 2, 1);
        for (final (id, created) in [
          ('s-b', DateTime.utc(2025, 2, 1, 8)),
          ('s-c', DateTime.utc(2025, 2, 1, 9)),
          ('s-a', DateTime.utc(2025, 2, 1, 9)),
          ('s-d', DateTime.utc(2025, 2, 1, 10)),
        ]) {
          await transactionsDao.insertTransaction(
            TransactionsCompanion(
              id: Value(id),
              accountId: const Value('acc1'),
              date: Value(day),
              amount: const Value(-100),
              createdAt: Value(created),
            ),
          );
        }
      });

      const sameDay = TransactionFilter(accountIds: ['acc1']);
      Future<List<String>> ids(TransactionSort? sort, {int? limit}) async => [
        for (final t in await transactionsDao.getTransactions(
          filter: sameDay,
          sort: sort,
          limit: limit,
        ))
          if (t.id.startsWith('s-')) t.id,
      ];

      test(
        'newest first: the latest entered row of a day comes first',
        () async {
          expect(await ids(null), ['s-d', 's-c', 's-a', 's-b']);
          expect(
            await ids(
              const TransactionSort(
                field: TransactionSortField.date,
                ascending: false,
              ),
            ),
            ['s-d', 's-c', 's-a', 's-b'],
          );
        },
      );

      test('oldest first reverses it', () async {
        expect(
          await ids(const TransactionSort(field: TransactionSortField.date)),
          ['s-b', 's-a', 's-c', 's-d'],
        );
      });

      test('equal amounts keep the date order', () async {
        expect(
          await ids(const TransactionSort(field: TransactionSortField.amount)),
          ['s-d', 's-c', 's-a', 's-b'],
        );
      });

      test('a page is a prefix of the next, larger page', () async {
        final all = await ids(null);
        expect(await ids(null, limit: 2), all.take(2).toList());
        expect(await ids(null, limit: 3), all.take(3).toList());
      });
    });
  });

  test('watchDailyTotals sums the live top-level rows of one account per '
      'day, oldest first (ledger improvement 1)', () async {
    Future<void> add(
      String id,
      String account,
      DateTime date,
      int amount, {
      String? parent,
      bool deleted = false,
    }) => transactionsDao.insertTransaction(
      TransactionsCompanion(
        id: Value(id),
        accountId: Value(account),
        date: Value(date),
        amount: Value(amount),
        parentTransactionId: Value(parent),
        isDeleted: Value(deleted),
      ),
    );
    final d1 = DateTime.utc(2025, 3, 1);
    final d2 = DateTime.utc(2025, 3, 2);
    await add('x1', 'acc2', d2, -300);
    await add('x2', 'acc2', d2, -200);
    await add('x3', 'acc2', d1, 1000);
    await add('split', 'acc2', d1, -400);
    await add('line1', 'acc2', d1, -100, parent: 'split');
    await add('line2', 'acc2', d1, -300, parent: 'split');
    await add('gone', 'acc2', d1, -9999, deleted: true);
    await add('other', 'acc1', d1, -7777);

    final totals = await transactionsDao.watchDailyTotals('acc2').first;
    // First the seed's t3 (1000.00 in January), then the two days above.
    expect(totals.map((d) => d.total), [100000, 600, -500]);
    expect(totals.skip(1).map((d) => d.date.toUtc()), [d1, d2]);
  });
}
