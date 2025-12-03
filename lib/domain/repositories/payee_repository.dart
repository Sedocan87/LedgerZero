import 'package:ledger_zero/domain/entities/payee.dart';

/// Repository interface for managing [Payee] entities.
abstract class PayeeRepository {
  /// Retrieves all payees.
  Future<List<Payee>> getAllPayees();

  /// Retrieves a payee by its unique identifier.
  Future<Payee?> getPayeeById(String id);

  /// Creates a new payee.
  Future<void> createPayee(Payee payee);

  /// Updates an existing payee.
  Future<void> updatePayee(Payee payee);

  /// Deletes a payee by its unique identifier.
  Future<void> deletePayee(String id);

  /// Watches all payees for changes.
  Stream<List<Payee>> watchAllPayees();

  /// Watches payees sorted by suggestions (Favorite, Usage, Recency).
  Stream<List<Payee>> watchSuggestedPayees();
}
