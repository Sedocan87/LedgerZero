import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  Future<List<Transaction>> getAllTransactions() => select(transactions).get();

  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction);

  Future<bool> updateTransaction(TransactionsCompanion transaction) =>
      update(transactions).replace(transaction);

  Future<int> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Stream<List<Transaction>> watchAllTransactions() =>
      select(transactions).watch();

  Future<List<Transaction>> getTransactionsByAccount(String accountId) =>
      (select(transactions)..where((t) => t.accountId.equals(accountId))).get();

  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) =>
      (select(transactions)..where((t) => t.accountId.equals(accountId)))
          .watch();

  Future<List<Transaction>> getTransactionsByDateRange(
          DateTime start, DateTime end) =>
      (select(transactions)..where((t) => t.date.isBetween(Variable(start), Variable(end))))
          .get();

  Future<double> getIncomeSumByDateRange(DateTime start, DateTime end) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(transactions.date.isBetween(Variable(start), Variable(end)) &
          transactions.amount.isBiggerThanValue(0) &
          transactions.categoryId.isNull())
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0.0).getSingle();
  }

  Future<double> getExpenseSumByCategoryAndDateRange(
      String categoryId, DateTime start, DateTime end) {
    final amount = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..where(transactions.date.isBetween(Variable(start), Variable(end)) &
          transactions.categoryId.equals(categoryId))
      ..addColumns([amount]);

    return query.map((row) => row.read(amount) ?? 0.0).getSingle();
  }
}
