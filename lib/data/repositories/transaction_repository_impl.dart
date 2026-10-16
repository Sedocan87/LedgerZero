import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/data/database/database_error_handler.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionsDao _transactionsDao;

  TransactionRepositoryImpl(this._transactionsDao);

  @override
  Future<List<Transaction>> getAllTransactions() async {
    return DatabaseErrorHandler.execute(() async {
      Logger.debug('Fetching all transactions');
      final transactions = await _transactionsDao.getAllTransactions();
      Logger.debug('Fetched ${transactions.length} transactions');
      return transactions.map(_mapToDomain).toList();
    }, context: 'getAllTransactions');
  }

  @override
  Future<void> updateTransferTransaction(
    Transaction source,
    Transaction destination,
  ) async {
    return DatabaseErrorHandler.execute(() async {
      Logger.debug(
        'Updating transfer between ${source.accountId} and ${destination.accountId}',
      );
      await _transactionsDao.db.transaction(() async {
        await _transactionsDao.updateTransaction(_mapToCompanion(source));
        await _transactionsDao.updateTransaction(_mapToCompanion(destination));
      });
      Logger.info('Transfer updated successfully');
    }, context: 'updateTransferTransaction');
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    return DatabaseErrorHandler.execute(() async {
      Logger.debug('Fetching transaction with id: $id');
      final transaction = await _transactionsDao.getTransactionById(id);
      Logger.debug('Transaction found: ${transaction != null}');
      return transaction == null ? null : _mapToDomain(transaction);
    }, context: 'getTransactionById');
  }

  @override
  Future<void> createTransaction(Transaction transaction) async {
    return DatabaseErrorHandler.execute(() async {
      Logger.debug('Creating transaction: ${transaction.id}');
      await _transactionsDao.insertTransaction(_mapToCompanion(transaction));
      Logger.info('Transaction created successfully: ${transaction.id}');
    }, context: 'createTransaction');
  }

  @override
  Future<void> batchCreateTransactions(List<Transaction> transactions) async {
    try {
      Logger.debug('Batch creating ${transactions.length} transactions');
      await _transactionsDao.batchCreateTransactions(
        transactions.map(_mapToCompanion).toList(),
      );
      Logger.info('Batch creation successful');
    } catch (e, stackTrace) {
      Logger.error('Failed to batch create transactions', e, stackTrace);
      throw DatabaseException('Failed to batch create transactions', e);
    }
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    try {
      Logger.debug('Updating transaction: ${transaction.id}');
      await _transactionsDao.updateTransaction(_mapToCompanion(transaction));
      Logger.info('Transaction updated successfully: ${transaction.id}');
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to update transaction ${transaction.id}',
        e,
        stackTrace,
      );
      throw DatabaseException(
        'Failed to update transaction ${transaction.id}',
        e,
      );
    }
  }

  @override
  Future<void> batchUpdateTransactions(List<Transaction> transactions) async {
    try {
      Logger.debug('Batch updating ${transactions.length} transactions');
      await _transactionsDao.batchUpdateTransactions(
        transactions.map(_mapToCompanion).toList(),
      );
      Logger.info('Batch update successful');
    } catch (e, stackTrace) {
      Logger.error('Failed to batch update transactions', e, stackTrace);
      throw DatabaseException('Failed to batch update transactions', e);
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      Logger.debug('Soft deleting transaction: $id');
      await _transactionsDao.softDeleteTransaction(id);
      Logger.info('Transaction soft deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete transaction $id', e, stackTrace);
      throw DatabaseException('Failed to delete transaction $id', e);
    }
  }

  @override
  Future<void> batchDeleteTransactions(List<String> ids) async {
    try {
      Logger.debug('Batch deleting ${ids.length} transactions');
      await _transactionsDao.batchSoftDeleteTransactions(ids);
      Logger.info('Batch delete successful');
    } catch (e, stackTrace) {
      Logger.error('Failed to batch delete transactions', e, stackTrace);
      throw DatabaseException('Failed to batch delete transactions', e);
    }
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return _transactionsDao
        .watchAllTransactions()
        .map((transactions) {
          return transactions.map(_mapToDomain).toList();
        })
        .handleError((error, stackTrace) {
          Logger.error(
            'Error in watchAllTransactions stream',
            error,
            stackTrace,
          );
          throw DatabaseException('Error watching transactions', error);
        });
  }

  @override
  Future<List<Transaction>> getTransactionsByAccount(String accountId) async {
    try {
      Logger.debug('Fetching transactions for account: $accountId');
      final transactions = await _transactionsDao.getTransactionsByAccount(
        accountId,
      );
      Logger.debug(
        'Fetched ${transactions.length} transactions for account $accountId',
      );
      return transactions.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to fetch transactions for account $accountId',
        e,
        stackTrace,
      );
      throw DatabaseException(
        'Failed to fetch transactions for account $accountId',
        e,
      );
    }
  }

  @override
  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) {
    return _transactionsDao
        .watchTransactionsByAccount(accountId)
        .map((transactions) {
          return transactions.map(_mapToDomain).toList();
        })
        .handleError((error, stackTrace) {
          Logger.error(
            'Error in watchTransactionsByAccount stream for account $accountId',
            error,
            stackTrace,
          );
          throw DatabaseException(
            'Error watching transactions for account $accountId',
            error,
          );
        });
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime end, {
    bool excludeSplitParents = false,
    bool excludeSplitChildren = false,
  }) async {
    try {
      final transactions = await _transactionsDao.getTransactionsByDateRange(
        start,
        end,
        excludeSplitParents: excludeSplitParents,
        excludeSplitChildren: excludeSplitChildren,
      );
      return transactions.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to fetch transactions in range $start - $end',
        e,
        stackTrace,
      );
      throw DatabaseException('Failed to fetch transactions in range', e);
    }
  }

  Future<T> _sum<T>(String what, Future<T> Function() query) async {
    try {
      return await query();
    } catch (e, stackTrace) {
      Logger.error('Failed to calculate $what', e, stackTrace);
      throw DatabaseException('Failed to calculate $what', e);
    }
  }

  @override
  Future<int> getReadyToAssignSum(DateTime start, DateTime end) => _sum(
    'ready-to-assign sum',
    () => _transactionsDao.getReadyToAssignSum(start, end),
  );

  @override
  Future<int> getIncomeSum(DateTime start, DateTime end) =>
      _sum('income sum', () => _transactionsDao.getIncomeSum(start, end));

  @override
  Future<int> getBalanceChangeSum(DateTime endExclusive) => _sum(
    'balance change sum',
    () => _transactionsDao.getBalanceChangeSum(endExclusive),
  );

  @override
  Future<Map<String, int>> getMonthlyBalanceChanges(
    DateTime start,
    DateTime endExclusive,
  ) async {
    try {
      return await _transactionsDao.getMonthlyBalanceChanges(
        start,
        endExclusive,
      );
    } catch (e, st) {
      Logger.error('Error loading monthly balance changes', e, st);
      throw DatabaseException('Error loading monthly balance changes', e);
    }
  }

  @override
  Future<int> getOutflowSum(DateTime start, DateTime end) =>
      _sum('outflow sum', () => _transactionsDao.getOutflowSum(start, end));

  @override
  Future<int> getCategoryActivitySum(
    String categoryId,
    DateTime start,
    DateTime end,
  ) => _sum(
    'activity of category $categoryId',
    () => _transactionsDao.getCategoryActivitySum(categoryId, start, end),
  );

  @override
  Future<Map<String, int>> getCategoryActivitySums(
    DateTime start,
    DateTime end,
  ) => _sum(
    'category activity sums',
    () => _transactionsDao.getCategoryActivitySums(start, end),
  );

  @override
  Future<Transaction?> getTransactionByIdIncludingDeleted(String id) async {
    return DatabaseErrorHandler.execute(() async {
      final row = await _transactionsDao.getTransactionByIdIncludingDeleted(id);
      return row == null ? null : _mapToDomain(row);
    }, context: 'getTransactionByIdIncludingDeleted');
  }

  @override
  Future<List<Transaction>> getTransactionsByIdsIncludingDeleted(
    List<String> ids,
  ) async {
    return DatabaseErrorHandler.execute(() async {
      final rows = await _transactionsDao.getTransactionsByIdsIncludingDeleted(
        ids,
      );
      return rows.map(_mapToDomain).toList();
    }, context: 'getTransactionsByIdsIncludingDeleted');
  }

  @override
  Future<void> upsertTransactions(List<Transaction> transactions) async {
    return DatabaseErrorHandler.execute(() async {
      await _transactionsDao.upsertTransactions(
        transactions.map(_mapToCompanion).toList(),
      );
    }, context: 'upsertTransactions');
  }

  @override
  Future<bool> insertTransactionOrIgnore(Transaction transaction) async {
    return DatabaseErrorHandler.execute(
      () => _transactionsDao.insertTransactionOrIgnore(
        _mapToCompanion(transaction),
      ),
      context: 'insertTransactionOrIgnore',
    );
  }

  @override
  Future<bool> isSplitParent(String id) async {
    return DatabaseErrorHandler.execute(
      () => _transactionsDao.isSplitParent(id),
      context: 'isSplitParent',
    );
  }

  @override
  Stream<Set<String>> watchSplitParentIds() =>
      _transactionsDao.watchSplitParentIds();

  @override
  Future<List<String>> markClearedAsReconciled(
    String accountId,
    DateTime upTo,
  ) async {
    return DatabaseErrorHandler.execute(
      () => _transactionsDao.markClearedAsReconciled(
        accountId,
        CalendarDate.normalize(upTo),
      ),
      context: 'markClearedAsReconciled',
    );
  }

  @override
  Future<void> createTransferTransaction(
    Transaction source,
    Transaction destination,
  ) async {
    try {
      Logger.debug(
        'Creating transfer between ${source.accountId} and ${destination.accountId}',
      );
      await _transactionsDao.db.transaction(() async {
        await _transactionsDao.insertTransaction(_mapToCompanion(source));
        await _transactionsDao.insertTransaction(_mapToCompanion(destination));
      });
      Logger.info('Transfer created successfully');
    } catch (e, stackTrace) {
      Logger.error('Failed to create transfer', e, stackTrace);
      throw DatabaseException('Failed to create transfer', e);
    }
  }

  @override
  Future<void> deleteLinkedTransaction(String id) async {
    try {
      Logger.debug('Deleting linked transaction: $id');
      await _transactionsDao.db.transaction(() async {
        final transaction = await _transactionsDao.getTransactionById(id);
        if (transaction == null) {
          return;
        }

        // Delete the transaction itself
        await _transactionsDao.softDeleteTransaction(id);

        // If transfer, delete counterpart
        if (transaction.transferTransactionId != null) {
          await _transactionsDao.softDeleteTransaction(
            transaction.transferTransactionId!,
          );
        }

        // If parent of split, delete children
        final children = await _transactionsDao.getSplitTransactions(id);
        for (var child in children) {
          await _transactionsDao.softDeleteTransaction(child.id);
        }
      });
      Logger.info('Linked transaction deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete linked transaction $id', e, stackTrace);
      throw DatabaseException('Failed to delete linked transaction $id', e);
    }
  }

  @override
  Future<void> createSplitTransaction(
    Transaction parent,
    List<Transaction> children,
  ) async {
    try {
      Logger.debug('Creating split transaction parent: ${parent.id}');
      await _transactionsDao.db.transaction(() async {
        await _transactionsDao.insertTransaction(_mapToCompanion(parent));
        for (var child in children) {
          await _transactionsDao.insertTransaction(_mapToCompanion(child));
        }
      });
      Logger.info('Split transaction created successfully');
    } catch (e, stackTrace) {
      Logger.error('Failed to create split transaction', e, stackTrace);
      throw DatabaseException('Failed to create split transaction', e);
    }
  }

  @override
  Future<void> updateSplitTransaction(
    Transaction parent,
    List<Transaction> children,
  ) async {
    try {
      Logger.debug('Updating split transaction parent: ${parent.id}');
      await _transactionsDao.db.transaction(() async {
        await _transactionsDao.updateTransaction(_mapToCompanion(parent));

        final existingChildren = await _transactionsDao.getSplitTransactions(
          parent.id,
        );
        final keptIds = children.map((c) => c.id).toSet();
        final removedIds = existingChildren
            .map((t) => t.id)
            .where((id) => !keptIds.contains(id))
            .toList();
        await _transactionsDao.batchSoftDeleteTransactions(removedIds);

        // Upsert by id: existing children are updated in place, new ones
        // inserted.
        await _transactionsDao.upsertTransactions(
          children.map(_mapToCompanion).toList(),
        );
      });
      Logger.info('Split transaction updated successfully');
    } catch (e, stackTrace) {
      Logger.error('Failed to update split transaction', e, stackTrace);
      throw DatabaseException('Failed to update split transaction', e);
    }
  }

  @override
  Future<List<Transaction>> getSplitTransactions(String parentId) async {
    try {
      Logger.debug('Fetching split transactions for parent: $parentId');
      final transactions = await _transactionsDao.getSplitTransactions(
        parentId,
      );
      Logger.debug('Fetched ${transactions.length} split transactions');
      return transactions.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error(
        'Failed to fetch split transactions for $parentId',
        e,
        stackTrace,
      );
      throw DatabaseException('Failed to fetch split transactions', e);
    }
  }

  @override
  Future<List<Transaction>> getTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  }) async {
    try {
      Logger.debug('Fetching transactions with filter and sort');
      final transactions = await _transactionsDao.getTransactions(
        filter: filter,
        sort: sort,
        limit: limit,
      );
      Logger.debug('Fetched ${transactions.length} transactions');
      return transactions.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch transactions with filter', e, stackTrace);
      throw DatabaseException('Failed to fetch transactions with filter', e);
    }
  }

  @override
  Stream<List<Transaction>> watchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  }) {
    return _transactionsDao
        .watchTransactions(filter: filter, sort: sort, limit: limit)
        .map((transactions) {
          return transactions.map(_mapToDomain).toList();
        })
        .handleError((error, stackTrace) {
          Logger.error('Error in watchTransactions stream', error, stackTrace);
          throw DatabaseException('Error watching transactions', error);
        });
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
      isDeleted: t.isDeleted,
      transferAccountId: t.transferAccountId,
      transferTransactionId: t.transferTransactionId,
      parentTransactionId: t.parentTransactionId,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    );
  }

  /// Dates are stored as UTC midnight of the calendar day; timestamps as
  /// UTC. `updatedAt` is always set to now.
  db.TransactionsCompanion _mapToCompanion(Transaction t) {
    final now = DateTime.now().toUtc();
    return db.TransactionsCompanion(
      id: Value(t.id),
      accountId: Value(t.accountId),
      date: Value(CalendarDate.normalize(t.date)),
      amount: Value(t.amount),
      payeeId: Value(t.payeeId),
      categoryId: Value(t.categoryId),
      memo: Value(t.memo),
      cleared: Value(t.cleared.index),
      approved: Value(t.approved),
      isDeleted: Value(t.isDeleted),
      transferAccountId: Value(t.transferAccountId),
      transferTransactionId: Value(t.transferTransactionId),
      parentTransactionId: Value(t.parentTransactionId),
      createdAt: Value(t.createdAt?.toUtc() ?? now),
      updatedAt: Value(now),
    );
  }
}
