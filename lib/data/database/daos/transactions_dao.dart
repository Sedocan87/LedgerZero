import 'package:drift/drift.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';
import 'package:ledger_zero/domain/entities/transaction.dart'
    show TransactionClearStatus;
import 'package:ledger_zero/domain/entities/transaction_filter.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Payees, Categories])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Future<List<Transaction>> getAllTransactions() =>
      (select(transactions)..where((t) => t.isDeleted.equals(false))).get();

  /// A non-deleted transaction by id (soft-deleted rows are not returned).
  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)
            ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
          .getSingleOrNull();

  /// A transaction by id, including soft-deleted rows (undo/restore).
  Future<Transaction?> getTransactionByIdIncludingDeleted(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Transactions by id, including soft-deleted rows.
  Future<List<Transaction>> getTransactionsByIdsIncludingDeleted(
    List<String> ids,
  ) => ids.isEmpty
      ? Future.value(const [])
      : (select(transactions)..where((t) => t.id.isIn(ids))).get();

  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction);

  /// Inserts [transaction] unless a row with the same id exists. Returns
  /// whether a row was inserted.
  Future<bool> insertTransactionOrIgnore(
    TransactionsCompanion transaction,
  ) async {
    final rowId = await into(
      transactions,
    ).insert(transaction, mode: InsertMode.insertOrIgnore);
    // sqlite reports the previous rowid when nothing was inserted, so check
    // the change count instead.
    final changes = await customSelect('SELECT changes() AS c').getSingle();
    return rowId > 0 && changes.read<int>('c') > 0;
  }

  /// Inserts or fully replaces each row (by id).
  Future<void> upsertTransactions(List<TransactionsCompanion> list) async {
    await batch((batch) {
      for (final row in list) {
        batch.insert(transactions, row, onConflict: DoUpdate((_) => row));
      }
    });
  }

  Future<void> batchCreateTransactions(List<TransactionsCompanion> list) async {
    await batch((batch) {
      batch.insertAll(transactions, list);
    });
  }

  Future<bool> updateTransaction(TransactionsCompanion transaction) =>
      update(transactions).replace(transaction);

  Future<int> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> softDeleteTransaction(String id) =>
      (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> batchUpdateTransactions(List<TransactionsCompanion> list) async {
    await batch((batch) {
      batch.replaceAll(transactions, list);
    });
  }

  Future<void> batchSoftDeleteTransactions(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await (update(transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)..where((t) => t.isDeleted.equals(false))).watch();

  Future<List<Transaction>> getTransactionsByAccount(String accountId) =>
      (select(transactions)..where(
            (t) => t.accountId.equals(accountId) & t.isDeleted.equals(false),
          ))
          .get();

  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) =>
      (select(transactions)..where(
            (t) => t.accountId.equals(accountId) & t.isDeleted.equals(false),
          ))
          .watch();

  /// `start <= date < endExclusive`. Dates are stored as UTC midnight; use
  /// [CalendarDate] to build the bounds.
  Expression<bool> _inRange(DateTime start, DateTime endExclusive) =>
      transactions.date.isBiggerOrEqualValue(start.toUtc()) &
      transactions.date.isSmallerThanValue(endExclusive.toUtc());

  /// SQL condition: the row of table `transactions` is a split parent, i.e.
  /// at least one non-deleted row references it as its parent.
  ///
  /// A split parent carries the account-side amount (it counts towards the
  /// account balance) while its children carry the categories (they count
  /// as category activity). It never counts towards income or To Be
  /// Budgeted itself.
  static const String splitParentCondition =
      'EXISTS (SELECT 1 FROM transactions AS split_child '
      'WHERE split_child.parent_transaction_id = transactions.id '
      'AND split_child.is_deleted = 0)';

  Expression<bool> get _isNotSplitParent =>
      const CustomExpression<bool>('NOT $splitParentCondition');

  /// Rows that flow into To Be Budgeted (decision D3): non-deleted,
  /// uncategorised, not a transfer leg and not a split parent. Both signs
  /// count (an uncategorised outflow reduces To Be Budgeted). Uncategorised
  /// split children count too: they are the part of a split that was not
  /// assigned to a category (the parent itself is excluded).
  Expression<bool> get _readyToAssignRow =>
      transactions.isDeleted.equals(false) &
      transactions.categoryId.isNull() &
      transactions.transferAccountId.isNull() &
      _isNotSplitParent;

  /// Non-deleted transactions with `start <= date < endExclusive`.
  ///
  /// [excludeSplitParents] drops split parents (use for per-category or
  /// per-payee aggregations, where the children carry the detail);
  /// [excludeSplitChildren] drops split children (use for account-side
  /// aggregations, where the parent carries the amount). Setting neither
  /// returns both, which double counts a split's amount.
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime endExclusive, {
    bool excludeSplitParents = false,
    bool excludeSplitChildren = false,
  }) =>
      (select(transactions)..where((t) {
            var where =
                _inRange(start, endExclusive) & t.isDeleted.equals(false);
            if (excludeSplitParents) {
              where = where & _isNotSplitParent;
            }
            if (excludeSplitChildren) {
              where = where & t.parentTransactionId.isNull();
            }
            return where;
          }))
          .get();

  /// Signed sum (minor units) of the rows that flow into To Be Budgeted
  /// (see [_readyToAssignRow]) with `start <= date < endExclusive`.
  Future<int> getReadyToAssignSum(DateTime start, DateTime endExclusive) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(_inRange(start, endExclusive) & _readyToAssignRow)
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0).getSingle();
  }

  /// Rows that make up account balances (decision D3): non-deleted and not
  /// a split child (the parent carries the account-side amount).
  Expression<bool> get _balanceRow =>
      transactions.isDeleted.equals(false) &
      transactions.parentTransactionId.isNull();

  /// Sum (minor units) of the balance rows (all accounts) dated before
  /// [endExclusive].
  Future<int> getBalanceChangeSum(DateTime endExclusive) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(
        transactions.date.isSmallerThanValue(endExclusive.toUtc()) &
            _balanceRow,
      )
      ..addColumns([amount]);
    return query.map((row) => row.read(amount) ?? 0).getSingle();
  }

  /// Net change of all account balances per calendar month (`yyyy-MM` ->
  /// signed sum in minor units) for `start <= date < endExclusive`,
  /// computed in one grouped query.
  Future<Map<String, int>> getMonthlyBalanceChanges(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final month = transactions.date.strftime('%Y-%m');
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(_inRange(start, endExclusive) & _balanceRow)
      ..addColumns([month, amount])
      ..groupBy([month]);
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(month) != null) row.read(month)!: row.read(amount) ?? 0,
    };
  }

  /// Income (minor units): the positive part of [getReadyToAssignSum], i.e.
  /// uncategorised inflows that are not transfers or split parents.
  Future<int> getIncomeSum(DateTime start, DateTime endExclusive) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(
        _inRange(start, endExclusive) &
            _readyToAssignRow &
            transactions.amount.isBiggerThanValue(0),
      )
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0).getSingle();
  }

  /// Spending (minor units, negative): the sum of all non-deleted outflows
  /// that are not transfer legs and not split parents (split children are
  /// counted instead of their parent).
  Future<int> getOutflowSum(DateTime start, DateTime endExclusive) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(
        _inRange(start, endExclusive) &
            transactions.isDeleted.equals(false) &
            transactions.transferAccountId.isNull() &
            transactions.amount.isSmallerThanValue(0) &
            _isNotSplitParent,
      )
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0).getSingle();
  }

  /// Activity (signed sum, minor units) of a category with
  /// `start <= date < endExclusive`: its non-deleted rows, split children
  /// included.
  Future<int> getCategoryActivitySum(
    String categoryId,
    DateTime start,
    DateTime endExclusive,
  ) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(
        _inRange(start, endExclusive) &
            transactions.categoryId.equals(categoryId) &
            transactions.isDeleted.equals(false),
      )
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0).getSingle();
  }

  Future<List<Transaction>> getSplitTransactions(String parentId) =>
      (select(transactions)..where(
            (t) =>
                t.parentTransactionId.equals(parentId) &
                t.isDeleted.equals(false),
          ))
          .get();

  /// Watches the ids of all split parents (rows with non-deleted children).
  Stream<Set<String>> watchSplitParentIds() {
    return customSelect(
      'SELECT DISTINCT parent_transaction_id AS id FROM transactions '
      'WHERE parent_transaction_id IS NOT NULL AND is_deleted = 0',
      readsFrom: {transactions},
    ).watch().map((rows) => {for (final r in rows) r.read<String>('id')});
  }

  /// Whether [id] is a split parent (has non-deleted children).
  Future<bool> isSplitParent(String id) async {
    final row = await customSelect(
      'SELECT 1 AS x FROM transactions c WHERE c.parent_transaction_id = ? '
      'AND c.is_deleted = 0 LIMIT 1',
      variables: [Variable.withString(id)],
      readsFrom: {transactions},
    ).getSingleOrNull();
    return row != null;
  }

  /// categoryId -> activity (signed sum, minor units) of categorised rows
  /// with `start <= date < endExclusive`.
  Future<Map<String, int>> getCategoryActivitySums(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(
        _inRange(start, endExclusive) &
            transactions.categoryId.isNotNull() &
            transactions.isDeleted.equals(false),
      )
      ..addColumns([transactions.categoryId, amount])
      ..groupBy([transactions.categoryId]);

    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(transactions.categoryId) != null)
          row.read(transactions.categoryId)!: row.read(amount) ?? 0,
    };
  }

  /// Marks the account's non-deleted `cleared` rows dated on or before
  /// [upTo] as reconciled (split children follow their parent). Returns the
  /// ids that changed.
  Future<List<String>> markClearedAsReconciled(
    String accountId,
    DateTime upTo,
  ) async {
    final rows =
        await (select(transactions)..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.isDeleted.equals(false) &
                  t.cleared.equals(TransactionClearStatus.cleared.index) &
                  t.date.isSmallerOrEqualValue(upTo.toUtc()),
            ))
            .get();
    final ids = rows.map((r) => r.id).toList();
    if (ids.isNotEmpty) {
      await (update(transactions)..where((t) => t.id.isIn(ids))).write(
        TransactionsCompanion(
          cleared: Value(TransactionClearStatus.reconciled.index),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
    return ids;
  }

  static String _likePattern(String text) {
    final escaped = text
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  Expression<bool> _buildWhereClause(TransactionFilter? filter) {
    Expression<bool> whereClause = transactions.isDeleted.equals(false);

    if (filter != null) {
      if (filter.ids != null && filter.ids!.isNotEmpty) {
        whereClause = whereClause & transactions.id.isIn(filter.ids!);
      }
      if (filter.accountIds != null && filter.accountIds!.isNotEmpty) {
        whereClause =
            whereClause & transactions.accountId.isIn(filter.accountIds!);
      }
      if (filter.categoryIds != null && filter.categoryIds!.isNotEmpty) {
        whereClause =
            whereClause & transactions.categoryId.isIn(filter.categoryIds!);
      }
      if (filter.payeeIds != null && filter.payeeIds!.isNotEmpty) {
        whereClause = whereClause & transactions.payeeId.isIn(filter.payeeIds!);
      }
      if (filter.startDate != null) {
        whereClause =
            whereClause &
            transactions.date.isBiggerOrEqualValue(
              CalendarDate.normalize(filter.startDate!),
            );
      }
      if (filter.endDate != null) {
        whereClause =
            whereClause &
            transactions.date.isSmallerThanValue(
              CalendarDate.endOfDayUtc(filter.endDate!),
            );
      }
      if (filter.minAmount != null) {
        whereClause =
            whereClause &
            transactions.amount.isBiggerOrEqualValue(filter.minAmount!);
      }
      if (filter.maxAmount != null) {
        whereClause =
            whereClause &
            transactions.amount.isSmallerOrEqualValue(filter.maxAmount!);
      }
      if (filter.minAbsAmount != null) {
        whereClause =
            whereClause &
            transactions.amount.abs().isBiggerOrEqualValue(
              filter.minAbsAmount!,
            );
      }
      if (filter.maxAbsAmount != null) {
        whereClause =
            whereClause &
            transactions.amount.abs().isSmallerOrEqualValue(
              filter.maxAbsAmount!,
            );
      }
      if (filter.memoSearch != null && filter.memoSearch!.isNotEmpty) {
        whereClause =
            whereClause &
            transactions.memo.like(
              _likePattern(filter.memoSearch!),
              escapeChar: r'\',
            );
      }
      final text = filter.searchText?.trim();
      if ((text != null && text.isNotEmpty) || filter.searchAmount != null) {
        Expression<bool>? search;
        if (text != null && text.isNotEmpty) {
          final pattern = _likePattern(text);
          final payeeIds = selectOnly(payees)
            ..addColumns([payees.id])
            ..where(payees.name.like(pattern, escapeChar: r'\'));
          final categoryIds = selectOnly(categories)
            ..addColumns([categories.id])
            ..where(categories.name.like(pattern, escapeChar: r'\'));
          search =
              transactions.memo.like(pattern, escapeChar: r'\') |
              transactions.payeeId.isInQuery(payeeIds) |
              transactions.categoryId.isInQuery(categoryIds);
        }
        if (filter.searchAmount != null) {
          final byAmount = transactions.amount.abs().equals(
            filter.searchAmount!.abs(),
          );
          search = search == null ? byAmount : (search | byAmount);
        }
        whereClause = whereClause & search!;
      }
      if (filter.excludeSplitChildren &&
          (filter.categoryIds == null || filter.categoryIds!.isEmpty)) {
        whereClause = whereClause & transactions.parentTransactionId.isNull();
      }
      if (filter.clearedStatuses != null &&
          filter.clearedStatuses!.isNotEmpty) {
        final indices = filter.clearedStatuses!.map((s) => s.index).toList();
        whereClause = whereClause & transactions.cleared.isIn(indices);
      }
    }
    return whereClause;
  }

  JoinedSelectStatement<HasResultSet, dynamic> _applyJoin(
    SimpleSelectStatement<HasResultSet, Transaction> query,
    TransactionSort? sort,
  ) {
    if (sort != null) {
      if (sort.field == TransactionSortField.payeeName) {
        return query.join([
          leftOuterJoin(payees, payees.id.equalsExp(transactions.payeeId)),
        ]);
      } else if (sort.field == TransactionSortField.categoryName) {
        return query.join([
          leftOuterJoin(
            categories,
            categories.id.equalsExp(transactions.categoryId),
          ),
        ]);
      }
    }
    return query.join([]);
  }

  List<OrderingTerm> _buildOrderBy(TransactionSort? sort) {
    if (sort == null) {
      return [
        OrderingTerm(expression: transactions.date, mode: OrderingMode.desc),
      ];
    }

    final mode = sort.ascending ? OrderingMode.asc : OrderingMode.desc;

    switch (sort.field) {
      case TransactionSortField.date:
        return [OrderingTerm(expression: transactions.date, mode: mode)];
      case TransactionSortField.amount:
        return [OrderingTerm(expression: transactions.amount, mode: mode)];
      case TransactionSortField.payeeName:
        return [OrderingTerm(expression: payees.name, mode: mode)];
      case TransactionSortField.categoryName:
        return [OrderingTerm(expression: categories.name, mode: mode)];
    }
  }

  Future<List<Transaction>> getTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  }) {
    final rootQuery = select(transactions);

    // Apply WHERE clause
    rootQuery.where((t) => _buildWhereClause(filter));

    // If we need to sort by joined tables
    if (sort != null &&
        (sort.field == TransactionSortField.payeeName ||
            sort.field == TransactionSortField.categoryName)) {
      final joinedQuery = _applyJoin(rootQuery, sort);
      joinedQuery.orderBy(_buildOrderBy(sort));
      if (limit != null) {
        joinedQuery.limit(limit);
      }
      return joinedQuery.map((row) => row.readTable(transactions)).get();
    } else {
      final terms = _buildOrderBy(sort);
      rootQuery.orderBy(
        terms
            .map(
              (term) =>
                  (t) => term,
            )
            .toList(),
      );
      if (limit != null) {
        rootQuery.limit(limit);
      }
      return rootQuery.get();
    }
  }

  Stream<List<Transaction>> watchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  }) {
    final rootQuery = select(transactions);

    // Apply WHERE clause
    rootQuery.where((t) => _buildWhereClause(filter));

    // If we need to sort by joined tables
    if (sort != null &&
        (sort.field == TransactionSortField.payeeName ||
            sort.field == TransactionSortField.categoryName)) {
      final joinedQuery = _applyJoin(rootQuery, sort);
      joinedQuery.orderBy(_buildOrderBy(sort));
      if (limit != null) {
        joinedQuery.limit(limit);
      }
      return joinedQuery.map((row) => row.readTable(transactions)).watch();
    } else {
      final terms = _buildOrderBy(sort);
      rootQuery.orderBy(
        terms
            .map(
              (term) =>
                  (t) => term,
            )
            .toList(),
      );
      if (limit != null) {
        rootQuery.limit(limit);
      }
      return rootQuery.watch();
    }
  }
}
