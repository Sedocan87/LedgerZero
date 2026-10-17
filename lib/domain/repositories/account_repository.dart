import 'package:ledger_zero/domain/entities/account.dart';

/// Repository interface for managing [Account] entities.
///
/// Every [Account] returned carries its computed [Account.balance]
/// (starting balance + SUM(amount) of its non-deleted transactions that are
/// not split children). The balance is never persisted.
abstract class AccountRepository {
  /// Retrieves all accounts.
  Future<List<Account>> getAllAccounts();

  /// Retrieves an account by its unique identifier.
  Future<Account?> getAccountById(String id);

  /// Creates a new account.
  Future<void> createAccount(Account account);

  /// Updates an existing account.
  ///
  /// The partner's accounts are never written. Making a personal account
  /// shared queues its transactions for sync (they were held back).
  Future<void> updateAccount(Account account);

  /// Whether account [id] has already synced to the household. A synced
  /// shared account cannot become personal any more: the partner's phone
  /// already has its transactions.
  Future<bool> wasSynced(String id);

  /// Deletes an account by its unique identifier.
  Future<void> deleteAccount(String id);

  /// Watches all accounts for changes (including balance changes caused by
  /// transactions).
  Stream<List<Account>> watchAllAccounts();

  /// Watches a specific account for changes.
  Stream<Account?> watchAccount(String id);

  /// accountId -> computed balance in minor units, for all accounts.
  Future<Map<String, int>> getAccountBalances();

  /// Watches accountId -> computed balance for all accounts.
  Stream<Map<String, int>> watchAccountBalances();

  /// Computed balance of one account in minor units (0 if unknown).
  Future<int> getAccountBalance(String id);

  /// Balance counting only cleared and reconciled transactions, optionally
  /// only those dated on or before the calendar day [upTo].
  Future<int> getClearedBalance(String id, {DateTime? upTo});

  /// Sum of the starting balances of the on-budget accounts (minor units).
  Future<int> getBudgetStartingBalance();
}
