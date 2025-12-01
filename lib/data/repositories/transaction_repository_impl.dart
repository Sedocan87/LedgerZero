import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionsDao _transactionsDao;

  TransactionRepositoryImpl(this._transactionsDao);

  @override
  Future<List<Transaction>> getAllTransactions() async {
    try {
      Logger.debug('Fetching all transactions');
      final transactions = await _transactionsDao.getAllTransactions();
      Logger.debug('Fetched ${transactions.length} transactions');
      return transactions.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch transactions', e, stackTrace);
      throw DatabaseException('Failed to fetch transactions', e);
    }
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    try {
      Logger.debug('Fetching transaction with id: $id');
      final transaction = await _transactionsDao.getTransactionById(id);
      Logger.debug('Transaction found: ${transaction != null}');
      return transaction == null ? null : _mapToDomain(transaction);
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch transaction $id', e, stackTrace);
      throw DatabaseException('Failed to fetch transaction $id', e);
    }
  }

  @override
  Future<void> createTransaction(Transaction transaction) async {
    try {
      Logger.debug('Creating transaction: ${transaction.id}');
      await _transactionsDao.insertTransaction(_mapToCompanion(transaction));
      Logger.info('Transaction created successfully: ${transaction.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create transaction ${transaction.id}', e, stackTrace);
      throw DatabaseException('Failed to create transaction ${transaction.id}', e);
    }
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    try {
      Logger.debug('Updating transaction: ${transaction.id}');
      await _transactionsDao.updateTransaction(_mapToCompanion(transaction));
      Logger.info('Transaction updated successfully: ${transaction.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update transaction ${transaction.id}', e, stackTrace);
      throw DatabaseException('Failed to update transaction ${transaction.id}', e);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      Logger.debug('Deleting transaction: $id');
      await _transactionsDao.deleteTransaction(id);
      Logger.info('Transaction deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete transaction $id', e, stackTrace);
      throw DatabaseException('Failed to delete transaction $id', e);
    }
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return _transactionsDao.watchAllTransactions().map(
      (transactions) {
        return transactions.map(_mapToDomain).toList();
      },
    ).handleError((error, stackTrace) {
      Logger.error('Error in watchAllTransactions stream', error, stackTrace);
      throw DatabaseException('Error watching transactions', error);
    });
  }

  @override
  Future<List<Transaction>> getTransactionsByAccount(String accountId) async {
    try {
      Logger.debug('Fetching transactions for account: $accountId');
      final transactions =
          await _transactionsDao.getTransactionsByAccount(accountId);
      Logger.debug('Fetched ${transactions.length} transactions for account $accountId');
      return transactions.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch transactions for account $accountId', e, stackTrace);
      throw DatabaseException('Failed to fetch transactions for account $accountId', e);
    }
  }

  @override
  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) {
    return _transactionsDao.watchTransactionsByAccount(accountId).map(
      (transactions) {
        return transactions.map(_mapToDomain).toList();
      },
    ).handleError((error, stackTrace) {
      Logger.error('Error in watchTransactionsByAccount stream for account $accountId', error, stackTrace);
      throw DatabaseException('Error watching transactions for account $accountId', error);
    });
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime start, DateTime end) async {
    try {
      Logger.debug('Fetching transactions between $start and $end');
      final transactions =
          await _transactionsDao.getTransactionsByDateRange(start, end);
      Logger.debug('Fetched ${transactions.length} transactions in range');
      return transactions.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch transactions in range $start - $end', e, stackTrace);
      throw DatabaseException('Failed to fetch transactions in range', e);
    }
  }

  @override
  Future<double> getIncomeSumByDateRange(DateTime start, DateTime end) async {
    try {
      return await _transactionsDao.getIncomeSumByDateRange(start, end);
    } catch (e, stackTrace) {
      Logger.error('Failed to calculate income sum', e, stackTrace);
      throw DatabaseException('Failed to calculate income sum', e);
    }
  }

  @override
  Future<double> getExpenseSumByCategoryAndDateRange(
      String categoryId, DateTime start, DateTime end) async {
    try {
      return await _transactionsDao.getExpenseSumByCategoryAndDateRange(
          categoryId, start, end);
    } catch (e, stackTrace) {
      Logger.error(
          'Failed to calculate expense sum for category $categoryId', e, stackTrace);
      throw DatabaseException('Failed to calculate expense sum', e);
    }
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
