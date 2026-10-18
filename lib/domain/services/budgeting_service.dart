import 'dart:math' as math;

import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:uuid/uuid.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_template_repository.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/domain/entities/enums/goal_type.dart';

/// Quick-fill rules of the budget row's quick actions.
enum AutoAssignRule {
  /// Budget what the category's goal still needs. Goals cannot be set in
  /// the app yet (goals UI is a planned feature), so this rule is not
  /// offered anywhere in the UI; the code is kept for when goals arrive.
  underfunded,
  averageSpent,
  lastMonthSpent,
  lastMonthBudgeted,
}

/// Service responsible for core budgeting calculations.
///
/// The budget identity (decision D3, see docs/BUDGETING_RULES.md):
///
/// * Category activity = SUM(amount) of the category's non-deleted rows
///   (split children included; split parents and transfer legs never carry
///   a category).
/// * Available(category, M) = max(0, Available(category, M - 1))
///   + budgeted in M + activity in M: a positive balance rolls over, a
///   negative one (cash overspending) is reset to zero and charged to the
///   next month's To Be Budgeted instead.
/// * TBB(M) = SUM(starting balances of the on-budget accounts that exist
///   by M) + SUM(rows flowing into To Be Budgeted up to end of M:
///   uncategorised, not a transfer leg, not a split parent, both signs)
///   - SUM(budgeted in any month, before, in or after M)
///   - SUM(overspending of the months before M).
/// * Invariant: SUM(available(M)) + TBB(M) + SUM(budgeted after M)
///   == SUM(account balances counting transactions up to end of M).
class BudgetingService {
  final TransactionRepository _transactionRepository;
  final BudgetRepository _budgetRepository;
  final CategoryRepository _categoryRepository;
  final BudgetTemplateRepository _budgetTemplateRepository;
  final AccountRepository _accountRepository;
  final UnitOfWork _unitOfWork;

  BudgetingService({
    required this._transactionRepository,
    required this._budgetRepository,
    required this._categoryRepository,
    required this._budgetTemplateRepository,
    required this._accountRepository,
    required this._unitOfWork,
  });

  /// Calculates "To Be Budgeted" (TBB) at the end of [targetMonth]:
  ///
  /// TBB = SUM(starting balances of the on-budget accounts that exist by
  ///       the month, see [_startingBalancesThrough])
  ///     + SUM(uncategorised, non-split-parent rows of on-budget accounts up
  ///       to the end of the month, both signs, transfer legs only when the
  ///       other account is off-budget)
  ///     - SUM(budgeted up to and including the month)
  ///     - SUM(budgeted in the months after it: money assigned to a future
  ///       month is no longer available now)
  ///     - SUM(cash overspending of the months before it: a negative
  ///       category balance is not carried into the next month's category
  ///       but taken out of To Be Budgeted, see [_rollTo]).
  ///
  /// Uncategorised outflows (and reconciliation adjustments) therefore
  /// reduce TBB, starting balances are budgetable, transfers between
  /// on-budget accounts do not change it, and off-budget (tracking)
  /// accounts only matter when money moves to or from them.
  Future<int> calculateTBB(DateTime targetMonth) async {
    final nextMonthStart = CalendarDate.endOfMonthUtc(targetMonth);
    final monthKey = CalendarDate.monthKey(targetMonth);

    final startingBalances = await _startingBalancesThrough(targetMonth);
    final readyToAssign = await _transactionRepository.getReadyToAssignSum(
      CalendarDate.beginningOfTime,
      nextMonthStart,
    );
    final roll = await _rollTo(targetMonth);
    final budgetedAfter = await _budgetRepository.getTotalBudgetedAfterMonth(
      monthKey,
    );

    return startingBalances +
        readyToAssign -
        roll.budgetedThrough -
        budgetedAfter -
        roll.overspentBefore;
  }

  /// Sum of the starting balances of the on-budget accounts that exist by
  /// the end of [month]. An account exists from the earlier of the month
  /// it was created in and the month of its first transaction (imported or
  /// backdated history), so a month before the account shows nothing of
  /// it; an account without a creation time always counts.
  Future<int> _startingBalancesThrough(DateTime month) async {
    final accounts = await _accountRepository.getAllAccounts();
    final firstDates = await _budgetRepository.getFirstTransactionDates();
    final end = CalendarDate.endOfMonthUtc(month);
    var total = 0;
    for (final account in accounts) {
      if (!account.onBudget) {
        continue;
      }
      final created = account.createdAt?.toUtc();
      final first = firstDates[account.id];
      final start = created == null
          ? null
          : (first != null && first.isBefore(created) ? first : created);
      if (start == null || start.isBefore(end)) {
        total += account.startingBalance;
      }
    }
    return total;
  }

  /// Rolls every category (or only [categoryId]) forward month by month
  /// from the first month with a budget or activity up to [month]:
  ///
  /// `available(M) = max(0, available(M - 1)) + budgeted(M) + activity(M)`
  ///
  /// A negative balance at the end of a month (cash overspending) does not
  /// reduce the category in the next month; it is counted in
  /// [_Rollover.overspentBefore] and taken out of To Be Budgeted there
  /// instead. Two grouped queries and an in-memory loop, whatever the
  /// number of months and categories.
  Future<_Rollover> _rollTo(DateTime month, {String? categoryId}) async {
    final monthKey = CalendarDate.monthKey(month);
    final budgets = await _budgetRepository.getBudgetsUpToMonth(
      monthKey,
      categoryId: categoryId,
    );
    final activity = await _budgetRepository.getMonthlyCategoryActivity(
      CalendarDate.endOfMonthUtc(month),
      categoryId: categoryId,
    );

    final budgetedByMonth = <String, Map<String, int>>{};
    var budgetedThrough = 0;
    for (final b in budgets) {
      final id = b.categoryId;
      if (id == null) {
        continue;
      }
      budgetedThrough += b.budgeted;
      final ofMonth = budgetedByMonth.putIfAbsent(b.month, () => {});
      ofMonth[id] = (ofMonth[id] ?? 0) + b.budgeted;
    }

    final months = {...budgetedByMonth.keys, ...activity.keys}.toList()..sort();
    final available = <String, int>{};
    var overspentBefore = 0;
    if (months.isEmpty) {
      return _Rollover(
        available: available,
        overspentBefore: 0,
        budgetedThrough: budgetedThrough,
      );
    }
    final first = CalendarDate.parseMonthKey(months.first);
    final count = _monthsDifference(first, month) + 1;
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        // Month boundary: last month's overspending leaves the category.
        for (final entry in available.entries.toList()) {
          if (entry.value < 0) {
            overspentBefore -= entry.value;
            available[entry.key] = 0;
          }
        }
      }
      final key = CalendarDate.monthKey(
        DateTime.utc(first.year, first.month + i, 1),
      );
      for (final MapEntry(key: id, value: amount)
          in (budgetedByMonth[key] ?? const <String, int>{}).entries) {
        available[id] = (available[id] ?? 0) + amount;
      }
      for (final MapEntry(key: id, value: amount)
          in (activity[key] ?? const <String, int>{}).entries) {
        available[id] = (available[id] ?? 0) + amount;
      }
    }
    return _Rollover(
      available: available,
      overspentBefore: overspentBefore,
      budgetedThrough: budgetedThrough,
    );
  }

  /// Total income for [month]: uncategorised inflows that are not transfer
  /// legs or split parents.
  Future<int> calculateTotalIncomeForMonth(DateTime month) async {
    return _transactionRepository.getIncomeSum(
      CalendarDate.startOfMonthUtc(month),
      CalendarDate.endOfMonthUtc(month),
    );
  }

  /// Total spending (negative) for [month]: outflows that are not transfer
  /// legs; a split counts through its children, never twice.
  Future<int> calculateTotalSpendingForMonth(DateTime month) async {
    return _transactionRepository.getOutflowSum(
      CalendarDate.startOfMonthUtc(month),
      CalendarDate.endOfMonthUtc(month),
    );
  }

  /// Calculates total budgeted amount for a specific [month].
  Future<int> calculateTotalBudgetedForMonth(DateTime month) async {
    final monthString = CalendarDate.monthKey(month);
    final budgets = await _budgetRepository.getBudgetsForMonth(monthString);

    return Money.sum(budgets.map((b) => b.budgeted));
  }

  /// Calculates the activity (spending) for a specific [categoryId] in a specific [month].
  ///
  /// Activity is the sum of all transactions for this category in the month.
  /// Usually negative for outflows/spending.
  Future<int> calculateCategoryActivity(
    String categoryId,
    DateTime month,
  ) async {
    final startOfMonth = CalendarDate.startOfMonthUtc(month);
    final endOfMonth = CalendarDate.endOfMonthUtc(month); // exclusive

    return await _transactionRepository.getCategoryActivitySum(
      categoryId,
      startOfMonth,
      endOfMonth,
    );
  }

  /// Calculates the available amount for a specific [categoryId] at the end
  /// of [month]: budgeted plus activity, rolled forward month by month with
  /// positive balances carried over and overspending reset (see [_rollTo]).
  Future<int> calculateCategoryAvailable(
    String categoryId,
    DateTime month,
  ) async {
    final roll = await _rollTo(month, categoryId: categoryId);
    return roll.available[categoryId] ?? 0;
  }

  /// Assigns a budgeted amount to a specific category for a specific month.
  ///
  /// If a budget already exists, updates it. Otherwise, creates a new one
  /// with the deterministic id of `budget:<categoryId>:<yyyy-MM>`.
  Future<void> setCategoryBudgetedAmount(
    String categoryId,
    int amount,
    DateTime month,
  ) async {
    await _unitOfWork.run(() => _writeBudget(categoryId, month, (_) => amount));
  }

  /// Sets the budget of [categoryId] in [month] to `compute(current)`,
  /// creating the row (deterministic id) when it does not exist.
  ///
  /// [stampedAt] replaces the current time as the row's `updated_at` (the
  /// sync conflict timestamp), see [fillEmptyCategories].
  Future<void> _writeBudget(
    String categoryId,
    DateTime month,
    int Function(int current) compute, {
    DateTime? stampedAt,
  }) async {
    final monthString = CalendarDate.monthKey(month);
    final now = DateTime.now().toUtc();
    final updatedAt = stampedAt ?? now;
    final existing = await _budgetRepository.getBudgetByCategoryAndMonth(
      categoryId,
      monthString,
    );
    if (existing != null) {
      await _budgetRepository.updateBudget(
        existing.copyWith(
          budgeted: compute(existing.budgeted),
          updatedAt: updatedAt,
        ),
      );
      return;
    }
    try {
      await _budgetRepository.createBudget(
        Budget(
          id: DeterministicId.budgetForKey(categoryId, monthString),
          categoryId: categoryId,
          month: monthString,
          budgeted: compute(0),
          createdAt: now,
          updatedAt: updatedAt,
        ),
      );
    } catch (e) {
      // The row was created concurrently (or arrived through sync):
      // update it instead.
      final retry = await _budgetRepository.getBudgetByCategoryAndMonth(
        categoryId,
        monthString,
      );
      if (retry == null) {
        rethrow;
      }
      await _budgetRepository.updateBudget(
        retry.copyWith(budgeted: compute(retry.budgeted), updatedAt: updatedAt),
      );
    }
  }

  /// Moves money from one category to another in a specific month.
  ///
  /// Reduces the budgeted amount in [fromCategoryId] and increases it in
  /// [toCategoryId] in one unit of work, so the total budgeted (and TBB)
  /// never changes, even if a write fails.
  Future<void> moveMoney(
    String fromCategoryId,
    String toCategoryId,
    int amount,
    DateTime month,
  ) async {
    await _unitOfWork.run(() async {
      await _writeBudget(fromCategoryId, month, (current) => current - amount);
      await _writeBudget(toCategoryId, month, (current) => current + amount);
    });
  }

  /// Initializes budget entries for a new month for all active categories.
  ///
  /// Ensures that a Budget entity exists for every category for the given month.
  Future<void> initializeMonthBudgets(DateTime month) async {
    final allCategories = await _categoryRepository.getAllCategories();
    await _unitOfWork.run(() async {
      for (final category in allCategories) {
        await _writeBudget(category.id, month, (current) => current);
      }
    });
  }

  /// Calculates the target amount to budget for a category for the given month based on its goal.
  Future<int> calculateGoalTarget(Category category, DateTime month) async {
    if (category.goalType == null || category.targetAmount == null) {
      return 0;
    }

    final targetAmount = category.targetAmount!;
    final prevMonth = DateTime.utc(month.year, month.month - 1, 1);

    switch (category.goalType!) {
      case GoalType.monthlyFunding:
        return targetAmount;

      case GoalType.targetBalance:
        final priorAvailable = await calculateCategoryAvailable(
          category.id,
          prevMonth,
        );
        final needed = targetAmount - priorAvailable;
        return needed > 0 ? needed : 0;

      case GoalType.targetBalanceByDate:
        if (category.targetDate == null) {
          return 0;
        }

        // Calculate months remaining, inclusive of current month and target month
        final monthsDiff = _monthsDifference(month, category.targetDate!);
        // If target date is in the past or this month, monthsDiff <= 0.
        // We want to treat "this month" as 1 month remaining.
        int monthsRemaining = monthsDiff + 1;

        if (monthsRemaining <= 0) {
          monthsRemaining = 1;
        }

        final priorAvailable = await calculateCategoryAvailable(
          category.id,
          prevMonth,
        );
        final needed = targetAmount - priorAvailable;

        if (needed <= 0) {
          return 0;
        }

        return Money.divideRounded(needed, monthsRemaining);
    }
  }

  /// Calculates the funded percentage for a category's goal in a specific month.
  /// Returns a value between 0.0 and 1.0 (or higher if overfunded).
  Future<double> calculateFundedPercentage(
    Category category,
    DateTime month,
  ) async {
    if (category.goalType == null ||
        category.targetAmount == null ||
        category.targetAmount == 0) {
      return 0.0;
    }

    final target = await calculateGoalTarget(category, month);
    if (target == 0) {
      return 1.0; // Goal met or no target needed
    }

    final monthString = CalendarDate.monthKey(month);
    final budget = await _budgetRepository.getBudgetByCategoryAndMonth(
      category.id,
      monthString,
    );
    final budgeted = budget?.budgeted ?? 0;

    // A ratio for display, not money.
    return budgeted / target;
  }

  /// Average spending of a category over the [months] months before
  /// [referenceMonth]: total net spending divided by the number of those
  /// months that had any activity (at least 1), so a category that is one
  /// month old is not averaged over three.
  Future<int> getAverageSpent(
    String categoryId,
    int months,
    DateTime referenceMonth,
  ) async {
    var total = 0;
    var monthsWithData = 0;
    for (var i = 1; i <= months; i++) {
      final activity = await calculateCategoryActivity(
        categoryId,
        DateTime.utc(referenceMonth.year, referenceMonth.month - i, 1),
      );
      if (activity != 0) {
        monthsWithData++;
        total += activity;
      }
    }
    return _netSpending(
      Money.divideRounded(total, math.max(1, monthsWithData)),
    );
  }

  /// Gets the spending in the previous month.
  Future<int> getLastMonthSpent(
    String categoryId,
    DateTime currentMonth,
  ) async {
    final prevMonth = DateTime.utc(
      currentMonth.year,
      currentMonth.month - 1,
      1,
    );
    final activity = await calculateCategoryActivity(categoryId, prevMonth);
    return _netSpending(activity);
  }

  /// Turns net category activity into an amount to budget: net outflows
  /// (negative activity) become a positive amount, net inflows (refunds
  /// exceeding spending) become zero rather than a positive budget.
  static int _netSpending(int activity) => activity < 0 ? -activity : 0;

  /// Gets the budgeted amount in the previous month.
  Future<int> getLastMonthBudgeted(
    String categoryId,
    DateTime currentMonth,
  ) async {
    final prevMonthString = CalendarDate.monthKey(
      DateTime.utc(currentMonth.year, currentMonth.month - 1, 1),
    );
    final budget = await _budgetRepository.getBudgetByCategoryAndMonth(
      categoryId,
      prevMonthString,
    );
    return budget?.budgeted ?? 0;
  }

  /// Automatically assigns budget to a category based on a rule.
  Future<void> autoAssign(
    String categoryId,
    DateTime month,
    AutoAssignRule rule,
  ) async {
    int amount = 0;

    switch (rule) {
      case AutoAssignRule.underfunded:
        final category = await _categoryRepository.getCategoryById(categoryId);
        if (category != null) {
          amount = await calculateGoalTarget(category, month);
        }
        break;
      case AutoAssignRule.averageSpent:
        amount = await getAverageSpent(
          categoryId,
          3,
          month,
        ); // Default to 3 months average
        break;
      case AutoAssignRule.lastMonthSpent:
        amount = await getLastMonthSpent(categoryId, month);
        break;
      case AutoAssignRule.lastMonthBudgeted:
        amount = await getLastMonthBudgeted(categoryId, month);
        break;
    }

    await setCategoryBudgetedAmount(categoryId, amount, month);
  }

  // --- Budget Templates ---

  Future<void> saveBudgetTemplate(String name, DateTime month) async {
    final monthString = CalendarDate.monthKey(month);
    final budgets = await _budgetRepository.getBudgetsForMonth(monthString);

    final Map<String, int> data = {};
    for (final budget in budgets) {
      if (budget.categoryId != null && budget.budgeted > 0) {
        data[budget.categoryId!] = budget.budgeted;
      }
    }

    final template = BudgetTemplate(
      id: const Uuid().v4(),
      name: name,
      data: data,
      createdAt: DateTime.now().toUtc(),
    );

    await _budgetTemplateRepository.createTemplate(template);
  }

  Future<void> applyBudgetTemplate(String templateId, DateTime month) async {
    final template = await _budgetTemplateRepository.getTemplateById(
      templateId,
    );
    if (template == null) {
      return;
    }

    await _unitOfWork.run(() async {
      for (final entry in template.data.entries) {
        await _writeBudget(entry.key, month, (_) => entry.value);
      }
    });
  }

  Future<List<BudgetTemplate>> getAllTemplates() {
    return _budgetTemplateRepository.getAllTemplates();
  }

  Future<void> deleteTemplate(String id) {
    return _budgetTemplateRepository.deleteTemplate(id);
  }

  // --- Bulk Operations ---

  Future<void> copyBudgetFromPreviousMonth(DateTime month) async {
    final prevMonth = DateTime.utc(month.year, month.month - 1, 1);
    final prevMonthString = CalendarDate.monthKey(prevMonth);

    final prevBudgets = await _budgetRepository.getBudgetsForMonth(
      prevMonthString,
    );

    await _unitOfWork.run(() async {
      for (final budget in prevBudgets) {
        if (budget.categoryId != null && budget.budgeted > 0) {
          await _writeBudget(budget.categoryId!, month, (_) => budget.budgeted);
        }
      }
    });
  }

  /// Adds [amount] to the budget of [categoryId] in [month].
  Future<void> addToCategoryBudget(
    String categoryId,
    int amount,
    DateTime month,
  ) async {
    await _unitOfWork.run(
      () => _writeBudget(categoryId, month, (current) => current + amount),
    );
  }

  /// Takes up to [amount] of budgeted money back out of [categoryId] into
  /// To Be Budgeted, e.g. after the account it was set aside for left the
  /// budget (its balance then leaves To Be Budgeted in every month).
  ///
  /// Budgets are reduced from the oldest month on, where the money was
  /// first assigned, so earlier months do not stay short. A month gives up
  /// only as much as keeps the category's available amount from turning
  /// negative in that or any later month (up to the later of [month] and
  /// its last budget), so spending that was covered stays covered. Budgets
  /// never go below zero. Returns the amount released.
  Future<int> releaseFromCategory(
    String categoryId,
    int amount,
    DateTime month,
  ) async {
    if (amount <= 0) {
      return 0;
    }
    final budgets =
        (await _budgetRepository.getAllBudgets())
            .where((b) => b.categoryId == categoryId && b.budgeted > 0)
            .toList()
          ..sort((a, b) => a.month.compareTo(b.month));
    if (budgets.isEmpty) {
      return 0;
    }
    final first = CalendarDate.parseMonthKey(budgets.first.month);
    final lastBudget = CalendarDate.parseMonthKey(budgets.last.month);
    final end = lastBudget.isAfter(month) ? lastBudget : month;
    final count = _monthsDifference(first, end) + 1;

    // Lowest available amount from each month to the end: how much budget
    // that month can give up without leaving a later month overspent.
    final lowestFrom = List<int>.filled(count, 0);
    for (var i = count - 1; i >= 0; i--) {
      final available = await calculateCategoryAvailable(
        categoryId,
        DateTime.utc(first.year, first.month + i, 1),
      );
      lowestFrom[i] = i == count - 1
          ? available
          : math.min(available, lowestFrom[i + 1]);
    }

    final plan = <DateTime, int>{};
    var released = 0;
    for (final budget in budgets) {
      final budgetMonth = CalendarDate.parseMonthKey(budget.month);
      final room = lowestFrom[_monthsDifference(first, budgetMonth)] - released;
      final take = math.min(budget.budgeted, math.min(amount - released, room));
      if (take > 0) {
        plan[budgetMonth] = take;
        released += take;
      }
      if (released >= amount) {
        break;
      }
    }
    if (plan.isEmpty) {
      return 0;
    }
    await _unitOfWork.run(() async {
      for (final MapEntry(key: budgetMonth, value: take) in plan.entries) {
        await _writeBudget(
          categoryId,
          budgetMonth,
          (current) => current - take,
        );
      }
    });
    return released;
  }

  // --- Filling a new month ---

  /// The sync timestamp of an automatic fill of [month]: its first day,
  /// 00:00 UTC (see [fillEmptyCategories]). A hand edit never has exactly
  /// this time, so sync can tell the two apart.
  static DateTime automaticFillStamp(DateTime month) =>
      CalendarDate.startOfMonthUtc(month);

  /// The positive budgets of the month before [month], per category.
  Future<Map<String, int>> budgetsOfPreviousMonth(DateTime month) async {
    final previous = DateTime.utc(month.year, month.month - 1, 1);
    final budgets = await _budgetRepository.getBudgetsForMonth(
      CalendarDate.monthKey(previous),
    );
    return {
      for (final b in budgets)
        if (b.categoryId != null && b.budgeted > 0) b.categoryId!: b.budgeted,
    };
  }

  /// The amounts of template [templateId]; null when it no longer exists.
  Future<Map<String, int>?> templateAmounts(String templateId) async {
    final template = await _budgetTemplateRepository.getTemplateById(
      templateId,
    );
    return template == null ? null : Map.of(template.data);
  }

  /// Whether nothing is budgeted in [month] (every category at zero).
  Future<bool> isMonthEmpty(DateTime month) async {
    final budgets = await _budgetRepository.getBudgetsForMonth(
      CalendarDate.monthKey(month),
    );
    return budgets.every((b) => b.budgeted == 0);
  }

  /// Writes [amounts] into the categories of [month] that have nothing
  /// budgeted, in one unit of work. Hidden and deleted categories and
  /// non-positive amounts are skipped. Returns what was written.
  ///
  /// [stampedAt] (the automatic fill uses [automaticFillStamp]) is
  /// stored as the rows' sync timestamp instead of the current time, so any
  /// edit made by hand during the month, on this phone or a paired one, is
  /// newer and wins, and two phones filling the same month agree. A category
  /// already written at or after [stampedAt] (e.g. set to zero on purpose)
  /// is left alone, so the timestamps only ever move forward.
  Future<Map<String, int>> fillEmptyCategories(
    DateTime month,
    Map<String, int> amounts, {
    DateTime? stampedAt,
  }) async {
    final filled = await planFill(month, amounts, stampedAt: stampedAt);
    if (filled.isEmpty) {
      return filled;
    }
    await _unitOfWork.run(() async {
      for (final MapEntry(key: categoryId, value: amount) in filled.entries) {
        await _writeBudget(
          categoryId,
          month,
          (_) => amount,
          stampedAt: stampedAt,
        );
      }
    });
    return filled;
  }

  /// What [fillEmptyCategories] would write, without writing it.
  Future<Map<String, int>> planFill(
    DateTime month,
    Map<String, int> amounts, {
    DateTime? stampedAt,
  }) async {
    final visible = {
      for (final c in await _categoryRepository.getAllCategories())
        if (!c.isHidden) c.id,
    };
    final existing = {
      for (final b in await _budgetRepository.getBudgetsForMonth(
        CalendarDate.monthKey(month),
      ))
        if (b.categoryId != null) b.categoryId!: b,
    };
    return {
      for (final MapEntry(key: categoryId, value: amount) in amounts.entries)
        if (amount > 0 &&
            visible.contains(categoryId) &&
            (existing[categoryId]?.budgeted ?? 0) == 0 &&
            !_editedSince(existing[categoryId]?.updatedAt, stampedAt))
          categoryId: amount,
    };
  }

  static bool _editedSince(DateTime? edited, DateTime? since) =>
      since != null && edited != null && !edited.isBefore(since);

  /// Undoes [fillEmptyCategories]: sets the [filled] categories of [month]
  /// back to zero, except those changed since.
  Future<void> undoFill(DateTime month, Map<String, int> filled) async {
    final current = {
      for (final b in await _budgetRepository.getBudgetsForMonth(
        CalendarDate.monthKey(month),
      ))
        if (b.categoryId != null) b.categoryId!: b.budgeted,
    };
    final unchanged = [
      for (final MapEntry(key: categoryId, value: amount) in filled.entries)
        if (current[categoryId] == amount) categoryId,
    ];
    if (unchanged.isEmpty) {
      return;
    }
    await _unitOfWork.run(() async {
      for (final categoryId in unchanged) {
        await _writeBudget(categoryId, month, (_) => 0);
      }
    });
  }

  Future<void> resetBudget(DateTime month) async {
    final monthString = CalendarDate.monthKey(month);
    final budgets = await _budgetRepository.getBudgetsForMonth(monthString);

    await _unitOfWork.run(() async {
      for (final budget in budgets) {
        if (budget.categoryId != null && budget.budgeted != 0) {
          await _writeBudget(budget.categoryId!, month, (_) => 0);
        }
      }
    });
  }

  int _monthsDifference(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + to.month - from.month;
  }

  /// Calculates activity and available amounts for all categories in a specific [month].
  ///
  /// Returns a map where the key is categoryId and the value is another map with 'activity' and 'available' keys.
  /// Three grouped queries (activity in the month, activity per month,
  /// budgets up to the month) and one in-memory rollover ([_rollTo]).
  Future<Map<String, Map<String, int>>> calculateBatchCategoryPerformance(
    DateTime month,
  ) async {
    final startOfMonth = CalendarDate.startOfMonthUtc(month);
    final endOfMonth = CalendarDate.endOfMonthUtc(month); // exclusive

    final currentActivityMap = await _transactionRepository
        .getCategoryActivitySums(startOfMonth, endOfMonth);
    final roll = await _rollTo(month);

    final Map<String, Map<String, int>> result = {};
    for (final catId in {...currentActivityMap.keys, ...roll.available.keys}) {
      result[catId] = {
        'activity': currentActivityMap[catId] ?? 0,
        'available': roll.available[catId] ?? 0,
      };
    }
    return result;
  }

  /// Calculates goal targets for a batch of categories for the given month.
  ///
  /// Returns a map where key is categoryId and value is the target amount.
  Future<Map<String, int>> calculateBatchGoalTargets(
    DateTime month,
    List<Category> categories,
  ) async {
    final prevMonth = DateTime.utc(month.year, month.month - 1, 1);

    // We need previous month's available amounts for some goal types
    // Optimization: Only calculate if we have categories that need it
    Map<String, Map<String, int>>? prevMonthPerformance;

    final needsPrevMonthData = categories.any(
      (c) =>
          c.goalType == GoalType.targetBalance ||
          c.goalType == GoalType.targetBalanceByDate,
    );

    if (needsPrevMonthData) {
      prevMonthPerformance = await calculateBatchCategoryPerformance(prevMonth);
    }

    final Map<String, int> results = {};

    for (final category in categories) {
      if (category.goalType == null || category.targetAmount == null) {
        results[category.id] = 0;
        continue;
      }

      final targetAmount = category.targetAmount!;

      switch (category.goalType!) {
        case GoalType.monthlyFunding:
          results[category.id] = targetAmount;
          break;

        case GoalType.targetBalance:
          final priorAvailable =
              prevMonthPerformance?[category.id]?['available'] ?? 0;
          final needed = targetAmount - priorAvailable;
          results[category.id] = needed > 0 ? needed : 0;
          break;

        case GoalType.targetBalanceByDate:
          if (category.targetDate == null) {
            results[category.id] = 0;
            break;
          }

          final monthsDiff = _monthsDifference(month, category.targetDate!);
          int monthsRemaining = monthsDiff + 1;
          if (monthsRemaining <= 0) {
            monthsRemaining = 1;
          }

          final priorAvailable =
              prevMonthPerformance?[category.id]?['available'] ?? 0;
          final needed = targetAmount - priorAvailable;

          if (needed <= 0) {
            results[category.id] = 0;
          } else {
            results[category.id] = Money.divideRounded(needed, monthsRemaining);
          }
          break;
      }
    }

    return results;
  }
}

/// Result of [BudgetingService._rollTo].
class _Rollover {
  /// categoryId -> available at the end of the month (categories with
  /// neither budgets nor activity are absent).
  final Map<String, int> available;

  /// Overspending (positive minor units) of all months before the month,
  /// charged to its To Be Budgeted.
  final int overspentBefore;

  /// Everything budgeted up to and including the month.
  final int budgetedThrough;

  const _Rollover({
    required this.available,
    required this.overspentBefore,
    required this.budgetedThrough,
  });
}
