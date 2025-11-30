import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionsDao _transactionsDao;

  TransactionRepositoryImpl(this._transactionsDao);

  @override
  Future<List<Transaction>> getAllTransactions() async {
    final transactions = await _transactionsDao.getAllTransactions();
    return transactions.map(_mapToDomain).toList();
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    final transaction = await _transactionsDao.getTransactionById(id);
    return transaction == null ? null : _mapToDomain(transaction);
  }

  @override
  Future<void> createTransaction(Transaction transaction) async {
    await _transactionsDao.insertTransaction(_mapToCompanion(transaction));
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    await _transactionsDao.updateTransaction(_mapToCompanion(transaction));
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _transactionsDao.deleteTransaction(id);
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return _transactionsDao.watchAllTransactions().map(
          (transactions) => transactions.map(_mapToDomain).toList(),
        );
  }

  @override
  Future<List<Transaction>> getTransactionsByAccount(String accountId) async {
    final transactions =
        await _transactionsDao.getTransactionsByAccount(accountId);
    return transactions.map(_mapToDomain).toList();
  }

  @override
  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) {
    return _transactionsDao.watchTransactionsByAccount(accountId).map(
          (transactions) => transactions.map(_mapToDomain).toList(),
        );
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    final transactions =
        await _transactionsDao.getTransactionsByDateRange(start, end);
    return transactions.map(_mapToDomain).toList();
  }

  Transaction _mapToDomain(db.Transaction t) {
    return Transaction(
      id: t.id,
      accountId: t.accountId,
      date: t.date,
      amount: t.amount,
      payeeId: t.payeeId,
      categoryId: t.categoryId,
      memo: t.memo,
      cleared: TransactionClearStatus.values[t.cleared],
      approved: t.approved,
      transferAccountId: t.transferAccountId,
      transferTransactionId: t.transferTransactionId,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    );
  }

  db.TransactionsCompanion _mapToCompanion(Transaction t) {
    return db.TransactionsCompanion(
      id: Value(t.id),
      accountId: Value(t.accountId),
      date: Value(t.date),
      amount: Value(t.amount),
      payeeId: Value(t.payeeId),
      categoryId: Value(t.categoryId),
      memo: Value(t.memo),
      cleared: Value(t.cleared.index),
      approved: Value(t.approved),
      transferAccountId: Value(t.transferAccountId),
      transferTransactionId: Value(t.transferTransactionId),
      createdAt: Value(t.createdAt),
      updatedAt: Value(t.updatedAt),
    );
  }
}
