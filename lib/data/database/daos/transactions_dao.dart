import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/categories.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions, Payees, Categories])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Future<List<Transaction>> getAllTransactions() => (select(transactions)
        ..where((t) => t.isDeleted.equals(false)))
      .get();

  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction);

  Future<bool> updateTransaction(TransactionsCompanion transaction) =>
      update(transactions).replace(transaction);

  Future<int> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> softDeleteTransaction(String id) =>
      (update(transactions)..where((t) => t.id.equals(id)))
          .write(const TransactionsCompanion(isDeleted: Value(true)));

  Future<void> batchUpdateTransactions(List<TransactionsCompanion> list) async {
    await batch((batch) {
      batch.replaceAll(transactions, list);
    });
  }

  Future<void> batchSoftDeleteTransactions(List<String> ids) async {
    await (update(transactions)..where((t) => t.id.isIn(ids)))
        .write(const TransactionsCompanion(isDeleted: Value(true)));
  }

  Stream<List<Transaction>> watchAllTransactions() =>
      (select(transactions)..where((t) => t.isDeleted.equals(false))).watch();

  Future<List<Transaction>> getTransactionsByAccount(String accountId) =>
      (select(transactions)
            ..where((t) =>
                t.accountId.equals(accountId) & t.isDeleted.equals(false)))
          .get();

  Stream<List<Transaction>> watchTransactionsByAccount(
          String accountId) =>
      (select(transactions)
            ..where((t) =>
                t.accountId.equals(accountId) & t.isDeleted.equals(false)))
          .watch();

  Future<List<Transaction>> getTransactionsByDateRange(
          DateTime start, DateTime end) =>
      (select(transactions)
            ..where((t) =>
                t.date.isBetween(Variable(start), Variable(end)) &
                t.isDeleted.equals(false)))
          .get();

  Future<double> getIncomeSumByDateRange(DateTime start, DateTime end) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(transactions.date.isBetween(Variable(start), Variable(end)) &
          transactions.amount.isBiggerThanValue(0) &
          transactions.categoryId.isNull() &
          transactions.parentTransactionId.isNull() &
          transactions.isDeleted.equals(false))
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0.0).getSingle();
  }

  Future<double> getExpenseSumByCategoryAndDateRange(
      String categoryId, DateTime start, DateTime end) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(transactions.date.isBetween(Variable(start), Variable(end)) &
          transactions.categoryId.equals(categoryId) &
          transactions.isDeleted.equals(false))
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0.0).getSingle();
  }

  Future<List<Transaction>> getSplitTransactions(String parentId) =>
      (select(transactions)
            ..where((t) =>
                t.parentTransactionId.equals(parentId) &
                t.isDeleted.equals(false)))
          .get();

  Expression<bool> _buildWhereClause(TransactionFilter? filter) {
    Expression<bool> whereClause = transactions.isDeleted.equals(false);

    if (filter != null) {
      if (filter.ids != null && filter.ids!.isNotEmpty) {
        whereClause = whereClause & transactions.id.isIn(filter.ids!);
      }
      if (filter.accountIds != null && filter.accountIds!.isNotEmpty) {
        whereClause = whereClause & transactions.accountId.isIn(filter.accountIds!);
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
            whereClause & transactions.date.isBiggerOrEqualValue(filter.startDate!);
      }
      if (filter.endDate != null) {
        whereClause =
            whereClause & transactions.date.isSmallerOrEqualValue(filter.endDate!);
      }
      if (filter.minAmount != null) {
        whereClause =
            whereClause & transactions.amount.isBiggerOrEqualValue(filter.minAmount!);
      }
      if (filter.maxAmount != null) {
        whereClause =
            whereClause & transactions.amount.isSmallerOrEqualValue(filter.maxAmount!);
      }
      if (filter.memoSearch != null && filter.memoSearch!.isNotEmpty) {
        whereClause = whereClause &
            transactions.memo.like('%${filter.memoSearch!}%');
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
      TransactionSort? sort) {
    if (sort != null) {
      if (sort.field == TransactionSortField.payeeName) {
        return query.join([
          leftOuterJoin(payees, payees.id.equalsExp(transactions.payeeId))
        ]);
      } else if (sort.field == TransactionSortField.categoryName) {
        return query.join([
          leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId))
        ]);
      }
    }
    return query.join([]);
  }

  List<OrderingTerm> _buildOrderBy(TransactionSort? sort) {
    if (sort == null) {
      return [OrderingTerm(expression: transactions.date, mode: OrderingMode.desc)];
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

  Future<List<Transaction>> getTransactions(
      {TransactionFilter? filter, TransactionSort? sort, int? limit}) {
    final rootQuery = select(transactions);

    // Apply WHERE clause
    rootQuery.where((t) => _buildWhereClause(filter));

    // If we need to sort by joined tables
    if (sort != null && (sort.field == TransactionSortField.payeeName || sort.field == TransactionSortField.categoryName)) {
       final joinedQuery = _applyJoin(rootQuery, sort);
       joinedQuery.orderBy(_buildOrderBy(sort));
       if (limit != null) joinedQuery.limit(limit);
       return joinedQuery.map((row) => row.readTable(transactions)).get();
    } else {
       final terms = _buildOrderBy(sort);
       rootQuery.orderBy(terms.map((term) => (t) => term).toList());
       if (limit != null) rootQuery.limit(limit);
       return rootQuery.get();
    }
  }

  Stream<List<Transaction>> watchTransactions(
      {TransactionFilter? filter, TransactionSort? sort, int? limit}) {
    final rootQuery = select(transactions);

    // Apply WHERE clause
    rootQuery.where((t) => _buildWhereClause(filter));

    // If we need to sort by joined tables
    if (sort != null && (sort.field == TransactionSortField.payeeName || sort.field == TransactionSortField.categoryName)) {
       final joinedQuery = _applyJoin(rootQuery, sort);
       joinedQuery.orderBy(_buildOrderBy(sort));
       if (limit != null) joinedQuery.limit(limit);
       return joinedQuery.map((row) => row.readTable(transactions)).watch();
    } else {
       final terms = _buildOrderBy(sort);
       rootQuery.orderBy(terms.map((term) => (t) => term).toList());
       if (limit != null) rootQuery.limit(limit);
       return rootQuery.watch();
    }
  }
}
