/// Bulk reference maintenance used when categories, groups, accounts or
/// payees are deleted or merged.
///
/// Every method touches all rows, including soft-deleted transactions (they
/// still hold foreign keys), and stamps `updated_at` on what it changes.
/// Callers run these inside a [UnitOfWork] together with the final delete.
abstract class ReferenceMaintenanceRepository {
  /// Points every reference to category [fromId] at [toId], or clears it
  /// when [toId] is `null`: transactions (including soft-deleted), payee
  /// default categories, scheduled transactions, parsing rules, parsing
  /// history and budget templates (template amounts are merged into
  /// [toId] or dropped).
  Future<void> reassignCategoryReferences(String fromId, String? toId);

  /// Moves the budget rows of category [fromId] to [toId], adding the
  /// budgeted amounts per month into the target's row (created with its
  /// deterministic id when missing). With [toId] `null` the rows are
  /// deleted.
  Future<void> moveBudgets(String fromId, String? toId);

  /// Moves all categories of group [fromGroupId] into [toGroupId].
  Future<void> moveCategoriesToGroup(String fromGroupId, String toGroupId);

  /// Number of non-deleted transactions with category [categoryId].
  Future<int> countTransactionsWithCategory(String categoryId);

  /// Number of categories in group [groupId].
  Future<int> countCategoriesInGroup(String groupId);

  /// Turns transfer legs in other accounts whose counterpart lives in
  /// [accountId] into normal uncategorised transactions (transfer links
  /// cleared). Returns how many live rows were converted.
  Future<int> detachTransfersInto(String accountId);

  /// Hard-deletes every transaction of [accountId] (including soft-deleted
  /// rows; split children first).
  Future<void> deleteTransactionsOfAccount(String accountId);

  /// Deletes the scheduled transactions of [accountId].
  Future<void> deleteScheduledTransactionsOfAccount(String accountId);

  /// Clears payee default-account references to [accountId].
  Future<void> clearPayeeDefaultAccount(String accountId);

  /// Points every reference to payee [fromId] at [toId], or clears it when
  /// [toId] is `null`: transactions (including soft-deleted), scheduled
  /// transactions, parsing rules and parsing history.
  Future<void> reassignPayeeReferences(String fromId, String? toId);
}
