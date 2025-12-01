import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';

/// Service responsible for managing transactions.
///
/// This service handles the business logic for creating, updating, and deleting
/// transactions, including validation and state management.
class TransactionService {
  final TransactionRepository _transactionRepository;

  TransactionService(this._transactionRepository);

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

      final transactionToUpdate = transaction.copyWith(
        updatedAt: DateTime.now(),
      );

      await _transactionRepository.updateTransaction(transactionToUpdate);
      Logger.info('Transaction updated: ${transactionToUpdate.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update transaction', e, stackTrace);
      rethrow;
    }
  }

  /// Soft-deletes a transaction by its ID.
  ///
  /// This method marks the transaction as deleted without removing it from the database.
  Future<void> deleteTransaction(String id) async {
    try {
      await _transactionRepository.deleteTransaction(id);
      Logger.info('Transaction deleted: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete transaction', e, stackTrace);
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
