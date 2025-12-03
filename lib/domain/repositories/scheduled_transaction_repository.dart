import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

/// Repository interface for managing [ScheduledTransaction] entities.
abstract class ScheduledTransactionRepository {
  /// Retrieves all scheduled transactions.
  Future<List<ScheduledTransaction>> getAllScheduledTransactions();

  /// Retrieves all scheduled transactions due on or before the given date.
  Future<List<ScheduledTransaction>> getDueScheduledTransactions(DateTime date);

  /// Retrieves a scheduled transaction by its unique identifier.
  Future<ScheduledTransaction?> getScheduledTransactionById(String id);

  /// Creates a new scheduled transaction.
  Future<void> createScheduledTransaction(ScheduledTransaction transaction);

  /// Updates an existing scheduled transaction.
  Future<void> updateScheduledTransaction(ScheduledTransaction transaction);

  /// Deletes a scheduled transaction by its unique identifier.
  Future<void> deleteScheduledTransaction(String id);

  /// Skips the next occurrence of a scheduled transaction.
  Future<void> skipScheduledTransaction(String id);

  /// Watches all scheduled transactions for changes.
  Stream<List<ScheduledTransaction>> watchAllScheduledTransactions();
}
