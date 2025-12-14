import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/domain/undo/transaction_undo_actions.dart';

/// Service responsible for managing transactions.
///
/// This service handles the business logic for creating, updating, and deleting
/// transactions, including validation and state management.
class TransactionService {
  final TransactionRepository _transactionRepository;
  final UndoService _undoService;

  TransactionService(this._transactionRepository, this._undoService);

  /// Creates a new transaction.
  ///
  /// This method validates the transaction and persists it to the repository.
  /// If [transaction.createdAt] is not set, it defaults to the current time.
  Future<void> createTransaction(Transaction transaction) async {
    try {
      final validationErrors = transaction.validate();
      if (validationErrors.isNotEmpty) {
        throw ValidationException(validationErrors.join(', '));
      }

      final transactionToCreate = transaction.copyWith(
        createdAt: transaction.createdAt ?? DateTime.now(),
        updatedAt: transaction.updatedAt ?? DateTime.now(),
        isDeleted: false,
      );

      await _transactionRepository.createTransaction(transactionToCreate);
      _undoService.addAction(
        CreateTransactionAction(_transactionRepository, transactionToCreate),
      );
      Logger.info('Transaction created: ${transactionToCreate.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create transaction', e, stackTrace);
      rethrow;
    }
  }

  /// Updates an existing transaction.
  ///
  /// This method validates the transaction and persists changes to the repository.
  /// It automatically updates the [updatedAt] field.
  Future<void> updateTransaction(Transaction transaction) async {
    try {
      final validationErrors = transaction.validate();
      if (validationErrors.isNotEmpty) {
        throw ValidationException(validationErrors.join(', '));
      }

      final oldTransaction = await _transactionRepository.getTransactionById(
        transaction.id,
      );

      final transactionToUpdate = transaction.copyWith(
        updatedAt: DateTime.now(),
      );

      await _transactionRepository.updateTransaction(transactionToUpdate);

      if (oldTransaction != null) {
        _undoService.addAction(
          UpdateTransactionAction(
            _transactionRepository,
            oldTransaction,
            transactionToUpdate,
          ),
        );
      }
      Logger.info('Transaction updated: ${transactionToUpdate.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update transaction', e, stackTrace);
      rethrow;
    }
  }

  /// Soft-deletes a transaction by its ID.
  ///
  /// This method marks the transaction as deleted without removing it from the database.
  /// If the transaction is linked (transfer or split), counterparts are also deleted.
  Future<void> deleteTransaction(String id) async {
    try {
      final transaction = await _transactionRepository.getTransactionById(id);
      if (transaction == null) {
        return;
      }

      Transaction? related;
      List<Transaction> children = [];

      if (transaction.transferTransactionId != null) {
        related = await _transactionRepository.getTransactionById(
          transaction.transferTransactionId!,
        );
      } else {
        children = await _transactionRepository.getSplitTransactions(id);
      }

      await _transactionRepository.deleteLinkedTransaction(id);

      _undoService.addAction(
        DeleteLinkedTransactionAction(
          _transactionRepository,
          transaction,
          relatedTransaction: related,
          children: children,
        ),
      );
      Logger.info('Transaction deleted: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete transaction', e, stackTrace);
      rethrow;
    }
  }

  /// Creates a transfer consisting of two linked transactions.
  Future<void> createTransferTransaction(
    Transaction source,
    Transaction destination,
  ) async {
    try {
      final sourceErrors = source.validate();
      final destErrors = destination.validate();
      if (sourceErrors.isNotEmpty || destErrors.isNotEmpty) {
        throw ValidationException([...sourceErrors, ...destErrors].join(', '));
      }

      final now = DateTime.now();
      final sourceToCreate = source.copyWith(
        transferTransactionId: destination.id,
        transferAccountId: destination.accountId,
        createdAt: source.createdAt ?? now,
        updatedAt: source.updatedAt ?? now,
        isDeleted: false,
      );
      final destToCreate = destination.copyWith(
        transferTransactionId: source.id,
        transferAccountId: source.accountId,
        createdAt: destination.createdAt ?? now,
        updatedAt: destination.updatedAt ?? now,
        isDeleted: false,
      );

      await _transactionRepository.createTransferTransaction(
        sourceToCreate,
        destToCreate,
      );
      _undoService.addAction(
        CreateTransferAction(
          _transactionRepository,
          sourceToCreate,
          destToCreate,
        ),
      );
      Logger.info('Transfer created: ${source.id} -> ${destination.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create transfer', e, stackTrace);
      rethrow;
    }
  }

  /// Creates a split transaction consisting of a parent and multiple children.
  Future<void> createSplitTransaction(
    Transaction parent,
    List<Transaction> children,
  ) async {
    try {
      final parentErrors = parent.validate();
      if (parentErrors.isNotEmpty) {
        throw ValidationException(parentErrors.join(', '));
      }

      final childrenSum = children.fold<double>(
        0.0,
        (sum, t) => sum + t.amount,
      );
      if ((childrenSum - parent.amount).abs() > 0.001) {
        throw ValidationException(
          'Split transactions sum $childrenSum does not match parent amount ${parent.amount}',
        );
      }

      final now = DateTime.now();
      final parentToCreate = parent.copyWith(
        createdAt: parent.createdAt ?? now,
        updatedAt: parent.updatedAt ?? now,
        isDeleted: false,
      );
      final childrenToCreate = children.map((c) {
        return c.copyWith(
          parentTransactionId: parent.id,
          accountId: parent.accountId, // Children belong to same account
          date: parent.date, // Children share date
          payeeId: parent.payeeId, // Children share payee (usually)
          createdAt: c.createdAt ?? now,
          updatedAt: c.updatedAt ?? now,
          isDeleted: false,
        );
      }).toList();

      await _transactionRepository.createSplitTransaction(
        parentToCreate,
        childrenToCreate,
      );
      _undoService.addAction(
        CreateSplitTransactionAction(
          _transactionRepository,
          parentToCreate,
          childrenToCreate,
        ),
      );
      Logger.info('Split transaction created: ${parent.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create split transaction', e, stackTrace);
      rethrow;
    }
  }

  /// Approves a transaction.
  Future<void> approveTransaction(String id) async {
    try {
      final t = await _transactionRepository.getTransactionById(id);
      if (t != null) {
        final updated = t.copyWith(approved: true);
        await _transactionRepository.updateTransaction(updated);
        _undoService.addAction(
          UpdateTransactionAction(_transactionRepository, t, updated),
        );
        Logger.info('Transaction approved: $id');
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to approve transaction $id', e, stackTrace);
      rethrow;
    }
  }

  /// Rejects a transaction (marks as unapproved).
  Future<void> rejectTransaction(String id) async {
    try {
      final t = await _transactionRepository.getTransactionById(id);
      if (t != null) {
        final updated = t.copyWith(approved: false);
        await _transactionRepository.updateTransaction(updated);
        _undoService.addAction(
          UpdateTransactionAction(_transactionRepository, t, updated),
        );
        Logger.info('Transaction rejected: $id');
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to reject transaction $id', e, stackTrace);
      rethrow;
    }
  }

  /// Updates the clearing status of a transaction.
  Future<void> updateClearingStatus(
    String id,
    TransactionClearStatus status,
  ) async {
    try {
      final t = await _transactionRepository.getTransactionById(id);
      if (t != null) {
        final updated = t.copyWith(cleared: status);
        await _transactionRepository.updateTransaction(updated);
        _undoService.addAction(
          UpdateTransactionAction(_transactionRepository, t, updated),
        );
        Logger.info('Transaction clearing status updated: $id -> $status');
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to update clearing status for $id', e, stackTrace);
      rethrow;
    }
  }

  /// Marks a list of transactions as reconciled.
  Future<void> markAsReconciled(List<String> ids) async {
    try {
      final transactions = await _transactionRepository.getTransactions(
        filter: TransactionFilter(ids: ids),
      );

      final updatedTransactions = transactions.map((t) {
        return t.copyWith(
          cleared: TransactionClearStatus.reconciled,
          updatedAt: DateTime.now(),
        );
      }).toList();

      await _transactionRepository.batchUpdateTransactions(updatedTransactions);
      _undoService.addAction(
        BatchUpdateTransactionsAction(
          _transactionRepository,
          transactions,
          updatedTransactions,
        ),
      );
      Logger.info('Transactions reconciled: ${ids.length}');
    } catch (e, stackTrace) {
      Logger.error('Failed to reconcile transactions', e, stackTrace);
      rethrow;
    }
  }

  /// Approves multiple transactions.
  Future<void> bulkApprove(List<String> ids) async {
    try {
      final transactions = await _transactionRepository.getTransactions(
        filter: TransactionFilter(ids: ids),
      );

      final updatedTransactions = transactions.map((t) {
        return t.copyWith(approved: true, updatedAt: DateTime.now());
      }).toList();

      await _transactionRepository.batchUpdateTransactions(updatedTransactions);
      _undoService.addAction(
        BatchUpdateTransactionsAction(
          _transactionRepository,
          transactions,
          updatedTransactions,
        ),
      );
      Logger.info('Transactions approved: ${ids.length}');
    } catch (e, stackTrace) {
      Logger.error('Failed to approve transactions', e, stackTrace);
      rethrow;
    }
  }

  /// Rejects (unapproves) multiple transactions.
  Future<void> bulkReject(List<String> ids) async {
    try {
      final transactions = await _transactionRepository.getTransactions(
        filter: TransactionFilter(ids: ids),
      );

      final updatedTransactions = transactions.map((t) {
        return t.copyWith(approved: false, updatedAt: DateTime.now());
      }).toList();

      await _transactionRepository.batchUpdateTransactions(updatedTransactions);
      _undoService.addAction(
        BatchUpdateTransactionsAction(
          _transactionRepository,
          transactions,
          updatedTransactions,
        ),
      );
      Logger.info('Transactions rejected: ${ids.length}');
    } catch (e, stackTrace) {
      Logger.error('Failed to reject transactions', e, stackTrace);
      rethrow;
    }
  }

  /// Soft-deletes multiple transactions.
  Future<void> bulkDelete(List<String> ids) async {
    try {
      final transactions = await _transactionRepository.getTransactions(
        filter: TransactionFilter(ids: ids),
      );
      await _transactionRepository.batchDeleteTransactions(ids);

      if (transactions.isNotEmpty) {
        _undoService.addAction(
          BatchDeleteTransactionsAction(_transactionRepository, transactions),
        );
      }
      Logger.info('Transactions deleted: ${ids.length}');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete transactions', e, stackTrace);
      rethrow;
    }
  }

  /// Searches and filters transactions based on criteria.
  Future<List<Transaction>> searchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
  }) async {
    try {
      return await _transactionRepository.getTransactions(
        filter: filter,
        sort: sort,
      );
    } catch (e, stackTrace) {
      Logger.error('Failed to search transactions', e, stackTrace);
      rethrow;
    }
  }

  /// Watches transactions based on criteria.
  Stream<List<Transaction>> watchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
  }) {
    return _transactionRepository.watchTransactions(filter: filter, sort: sort);
  }

  /// Finds potential duplicates for a given transaction.
  ///
  /// Criteria for duplication:
  /// - Same amount
  /// - Date within +/- 3 days
  /// - Same payee (if set)
  /// - Not the same transaction ID
  Future<List<Transaction>> findPotentialDuplicates(
    Transaction transaction,
  ) async {
    try {
      final filter = TransactionFilter(
        minAmount: transaction.amount,
        maxAmount: transaction.amount,
        startDate: transaction.date.subtract(const Duration(days: 3)),
        endDate: transaction.date.add(const Duration(days: 3)),
        payeeIds: transaction.payeeId != null ? [transaction.payeeId!] : null,
      );

      final candidates = await _transactionRepository.getTransactions(
        filter: filter,
      );

      return candidates.where((t) => t.id != transaction.id).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to find potential duplicates', e, stackTrace);
      rethrow;
    }
  }
}

/// Exception thrown when transaction validation fails.
class ValidationException implements Exception {
  final String message;

  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}
