import 'package:ledger_zero/domain/entities/budget.dart';

/// Repository interface for managing [Budget] entities.
abstract class BudgetRepository {
  /// Retrieves all budgets.
  Future<List<Budget>> getAllBudgets();

  /// Retrieves a budget by its unique identifier.
  Future<Budget?> getBudgetById(String id);

  /// Retrieves a budget for a specific category and month.
  Future<Budget?> getBudgetByCategoryAndMonth(String categoryId, String month);

  /// Retrieves all budgets for a specific month.
  Future<List<Budget>> getBudgetsForMonth(String month);

  /// Creates a new budget.
  Future<void> createBudget(Budget budget);

  /// Updates an existing budget.
  Future<void> updateBudget(Budget budget);

  /// Deletes a budget by its unique identifier.
  Future<void> deleteBudget(String id);

  /// Watches all budgets for a specific month.
  Stream<List<Budget>> watchBudgetsForMonth(String month);

  /// Calculates total budgeted amount (minor units) across all categories up to (and including) [endMonth].
  Future<int> getTotalBudgetedByMonthRange(String endMonth);

  /// Calculates total budgeted amount (minor units) for a specific category up to (and including) [endMonth].
  Future<int> getTotalBudgetedByCategoryAndMonthRange(
    String categoryId,
    String endMonth,
  );

  /// Calculates total budgeted amount (minor units) for all categories up to (and including) [endMonth].
  /// Returns a map where key is categoryId and value is the sum.
  Future<Map<String, int>> getAllTimeBudgetedSumsUpToMonth(String endMonth);

  /// Every budget row with `month <= endMonth` (optionally of one
  /// category), for the month-by-month rollover.
  Future<List<Budget>> getBudgetsUpToMonth(
    String endMonth, {
    String? categoryId,
  });

  /// Budgeted per month (`yyyy-MM` -> sum, minor units) of the months
  /// after [endMonth] (one grouped query; months without rows are absent).
  Future<Map<String, int>> getBudgetedByMonthAfter(String endMonth);

  /// Money arriving in To Be Budgeted per month: `yyyy-MM` -> sum (minor
  /// units) of the positive rows that flow into To Be Budgeted
  /// (`TransactionRepository.getReadyToAssignSum`, outflows left out) with
  /// `start <= date < endExclusive` (one grouped query; months without
  /// such rows are absent).
  Future<Map<String, int>> getMonthlyReadyToAssignInflows(
    DateTime start,
    DateTime endExclusive,
  );

  /// Category activity per month: `yyyy-MM` -> (categoryId -> signed sum,
  /// minor units) of the categorised activity rows (on-budget accounts,
  /// split lines included) dated before [endExclusive], optionally of one
  /// category. Months without activity are absent.
  Future<Map<String, Map<String, int>>> getMonthlyCategoryActivity(
    DateTime endExclusive, {
    String? categoryId,
  });

  /// accountId -> date of the account's earliest non-deleted transaction.
  Future<Map<String, DateTime>> getFirstTransactionDates();

  /// The rows the credit-card rules need one by one (dated before
  /// [endExclusive]), see `BudgetingService` and docs/ALGORITHMS.md:
  ///
  /// * every categorised activity row of a (month, category) in which the
  ///   category has a row in one of the budget cards [cardIds] (spending or
  ///   a refund), cash rows included, and every activity row categorised
  ///   into one of [paymentCategoryIds];
  /// * unless [categoryId] is given: the card legs of transfers between a
  ///   card and another on-budget account ([CardLedgerRow.isBudgetTransfer]).
  ///
  /// With [categoryId], only that category's rows (no transfer legs).
  Future<List<CardLedgerRow>> getCardLedgerRows(
    DateTime endExclusive, {
    required Set<String> cardIds,
    required Set<String> paymentCategoryIds,
    String? categoryId,
  });

  /// accountId -> sum (minor units) of the account's balance rows (not
  /// deleted, not a split line) dated before [endExclusive]; the starting
  /// balance is not included. Accounts without such rows are absent.
  Future<Map<String, int>> getBalanceChangesBefore(DateTime endExclusive);
}

/// One transaction row as the credit-card rules process it.
class CardLedgerRow {
  final String id;
  final String accountId;

  /// The category; null for a [isBudgetTransfer] leg.
  final String? categoryId;
  final int amount;
  final DateTime date;
  final DateTime? createdAt;
  final String? transferAccountId;

  /// The card's leg of a transfer to or from another on-budget account (a
  /// payment, a cash advance, a balance transfer between two cards).
  final bool isBudgetTransfer;

  const CardLedgerRow({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.createdAt,
    required this.transferAccountId,
    required this.isBudgetTransfer,
  });

  /// The fixed processing order within a month: date, then `created_at`
  /// (missing first), then id.
  static int compare(CardLedgerRow a, CardLedgerRow b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) {
      return byDate;
    }
    final ca = a.createdAt?.microsecondsSinceEpoch ?? -1;
    final cb = b.createdAt?.microsecondsSinceEpoch ?? -1;
    if (ca != cb) {
      return ca.compareTo(cb);
    }
    return a.id.compareTo(b.id);
  }
}
