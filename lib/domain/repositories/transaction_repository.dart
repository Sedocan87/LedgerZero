import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';

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

  /// Updates multiple transactions.
  Future<void> batchUpdateTransactions(List<Transaction> transactions);

  /// Deletes a transaction by its unique identifier.
  Future<void> deleteTransaction(String id);

  /// Deletes multiple transactions by their unique identifiers.
  Future<void> batchDeleteTransactions(List<String> ids);

  /// Watches all transactions for changes.
  Stream<List<Transaction>> watchAllTransactions();

  /// Retrieves transactions associated with a specific account.
  Future<List<Transaction>> getTransactionsByAccount(String accountId);

  /// Watches transactions associated with a specific account.
  Stream<List<Transaction>> watchTransactionsByAccount(String accountId);

  /// Retrieves transactions within a specific date range.
  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end);

  /// Calculates the total income (positive amount, null category) within a date range.
  Future<double> getIncomeSumByDateRange(DateTime start, DateTime end);

  /// Calculates the total expenses (sum of amounts) for a specific category within a date range.
  Future<double> getExpenseSumByCategoryAndDateRange(String categoryId, DateTime start, DateTime end);

  /// Creates a transfer consisting of two linked transactions.
  Future<void> createTransferTransaction(Transaction source, Transaction destination);

  /// Deletes a transaction and its linked counterparts (transfers or splits).
  Future<void> deleteLinkedTransaction(String id);

  /// Creates a split transaction consisting of a parent and multiple children.
  Future<void> createSplitTransaction(Transaction parent, List<Transaction> children);

  /// Retrieves the split children for a parent transaction.
  Future<List<Transaction>> getSplitTransactions(String parentId);

  /// Retrieves transactions matching the provided filter and sorted by the provided sort options.
  Future<List<Transaction>> getTransactions({TransactionFilter? filter, TransactionSort? sort, int? limit});

  /// Watches transactions matching the provided filter and sorted by the provided sort options.
  Stream<List<Transaction>> watchTransactions({TransactionFilter? filter, TransactionSort? sort, int? limit});
}
