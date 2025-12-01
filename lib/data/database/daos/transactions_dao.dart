import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
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

  Stream<List<Transaction>> watchAllTransactions() => (select(transactions)
        ..where((t) => t.isDeleted.equals(false)))
      .watch();

  Future<List<Transaction>> getTransactionsByAccount(String accountId) =>
      (select(transactions)
            ..where((t) =>
                t.accountId.equals(accountId) & t.isDeleted.equals(false)))
          .get();

  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) =>
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
}
