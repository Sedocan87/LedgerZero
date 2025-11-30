import 'package:ledger_zero/domain/entities/account.dart';

/// Repository interface for managing [Account] entities.
abstract class AccountRepository {
  /// Retrieves all accounts.
  Future<List<Account>> getAllAccounts();

  /// Retrieves an account by its unique identifier.
  Future<Account?> getAccountById(String id);

  /// Creates a new account.
  Future<void> createAccount(Account account);

  /// Updates an existing account.
  Future<void> updateAccount(Account account);

  /// Deletes an account by its unique identifier.
  Future<void> deleteAccount(String id);

  /// Watches all accounts for changes.
  Stream<List<Account>> watchAllAccounts();
}
