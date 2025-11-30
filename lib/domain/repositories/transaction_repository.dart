import 'package:ledger_zero/domain/entities/transaction.dart';

/// Repository interface for managing [Transaction] entities.
abstract class TransactionRepository {
  /// Retrieves all transactions.
  Future<List<Transaction>> getAllTransactions();

  /// Retrieves a transaction by its unique identifier.
  Future<Transaction?> getTransactionById(String id);

  /// Creates a new transaction.
  Future<void> createTransaction(Transaction transaction);

  /// Updates an existing transaction.
  Future<void> updateTransaction(Transaction transaction);

  /// Deletes a transaction by its unique identifier.
  Future<void> deleteTransaction(String id);

  /// Watches all transactions for changes.
  Stream<List<Transaction>> watchAllTransactions();

  /// Retrieves transactions associated with a specific account.
  Future<List<Transaction>> getTransactionsByAccount(String accountId);

  /// Watches transactions associated with a specific account.
  Stream<List<Transaction>> watchTransactionsByAccount(String accountId);

  /// Retrieves transactions within a specific date range.
  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end);
}
