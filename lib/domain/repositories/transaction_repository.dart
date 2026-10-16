import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';

/// Repository interface for managing [Transaction] entities.
abstract class TransactionRepository {
  /// Retrieves all transactions.
  Future<List<Transaction>> getAllTransactions();

  /// Retrieves a non-deleted transaction by its unique identifier
  /// (soft-deleted rows return `null`).
  Future<Transaction?> getTransactionById(String id);

  /// Retrieves a transaction by id including soft-deleted rows.
  Future<Transaction?> getTransactionByIdIncludingDeleted(String id);

  /// Retrieves transactions by id including soft-deleted rows.
  Future<List<Transaction>> getTransactionsByIdsIncludingDeleted(
    List<String> ids,
  );

  /// Inserts or replaces each transaction by id (all fields, including
  /// `isDeleted`). Used to restore snapshots (undo/redo).
  Future<void> upsertTransactions(List<Transaction> transactions);

  /// Inserts [transaction] unless a row with its id already exists. Returns
  /// whether it was inserted.
  Future<bool> insertTransactionOrIgnore(Transaction transaction);

  /// Whether [id] is a split parent (has non-deleted children).
  Future<bool> isSplitParent(String id);

  /// Watches the ids of all split parents.
  Stream<Set<String>> watchSplitParentIds();

  /// Marks the account's `cleared` transactions dated on or before [upTo]
  /// as reconciled. Returns the ids that changed.
  Future<List<String>> markClearedAsReconciled(String accountId, DateTime upTo);

  /// Creates a new transaction.
  Future<void> createTransaction(Transaction transaction);

  /// Creates multiple transactions.
  Future<void> batchCreateTransactions(List<Transaction> transactions);

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

  /// Retrieves transactions with `start <= date < endExclusive`.
  ///
  /// Dates are calendar days stored as UTC midnight; build bounds with
  /// `CalendarDate` (e.g. `startOfMonthUtc` / `endOfMonthUtc`).
  ///
  /// A split is stored as a parent (account-side amount, no category) plus
  /// children (categories). Pass [excludeSplitParents] for category/payee
  /// aggregations and [excludeSplitChildren] for account-side aggregations,
  /// otherwise a split's amount is counted twice.
  Future<List<Transaction>> getTransactionsByDateRange(
    DateTime start,
    DateTime endExclusive, {
    bool excludeSplitParents = false,
    bool excludeSplitChildren = false,
  });

  /// Signed sum (minor units) of the transactions that flow into To Be
  /// Budgeted (decision D3) with `start <= date < endExclusive`:
  /// non-deleted, uncategorised, not a transfer leg, not a split parent.
  /// Inflows add to To Be Budgeted, outflows reduce it.
  Future<int> getReadyToAssignSum(DateTime start, DateTime endExclusive);

  /// Income in minor units: the positive rows of [getReadyToAssignSum]
  /// (uncategorised inflows that are not transfers or split parents).
  Future<int> getIncomeSum(DateTime start, DateTime endExclusive);

  /// Sum (minor units) of all account-balance rows (non-deleted, not split
  /// children) dated before [endExclusive].
  Future<int> getBalanceChangeSum(DateTime endExclusive);

  /// Net change of all account balances per month (`yyyy-MM` -> signed
  /// minor units) for `start <= date < endExclusive` (one grouped query).
  Future<Map<String, int>> getMonthlyBalanceChanges(
    DateTime start,
    DateTime endExclusive,
  );

  /// Spending in minor units (negative): non-deleted outflows that are not
  /// transfer legs or split parents, with `start <= date < endExclusive`.
  Future<int> getOutflowSum(DateTime start, DateTime endExclusive);

  /// Activity of a category (signed sum, minor units, split children
  /// included) with `start <= date < endExclusive`.
  Future<int> getCategoryActivitySum(
    String categoryId,
    DateTime start,
    DateTime endExclusive,
  );

  /// categoryId -> activity (signed sum, minor units) with
  /// `start <= date < endExclusive`.
  Future<Map<String, int>> getCategoryActivitySums(
    DateTime start,
    DateTime endExclusive,
  );

  /// Creates a transfer consisting of two linked transactions.
  Future<void> createTransferTransaction(
    Transaction source,
    Transaction destination,
  );

  /// Updates a transfer consisting of two linked transactions.
  Future<void> updateTransferTransaction(
    Transaction source,
    Transaction destination,
  );

  /// Deletes a transaction and its linked counterparts (transfers or splits).
  Future<void> deleteLinkedTransaction(String id);

  /// Creates a split transaction consisting of a parent and multiple children.
  Future<void> createSplitTransaction(
    Transaction parent,
    List<Transaction> children,
  );

  /// Updates a split transaction (parent and children).
  ///
  /// Children are matched by id: existing ids are updated in place (their
  /// cleared/reconciled state and createdAt are what the caller passes),
  /// new ids are inserted and existing children missing from [children] are
  /// soft-deleted.
  Future<void> updateSplitTransaction(
    Transaction parent,
    List<Transaction> children,
  );

  /// Retrieves the split children for a parent transaction.
  Future<List<Transaction>> getSplitTransactions(String parentId);

  /// Retrieves transactions matching the provided filter and sorted by the provided sort options.
  Future<List<Transaction>> getTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  });

  /// Watches transactions matching the provided filter and sorted by the provided sort options.
  Stream<List<Transaction>> watchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  });
}
