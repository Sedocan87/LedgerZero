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
import 'package:ledger_zero/domain/entities/card_payments.dart';
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
///   - SUM(budgeted up to and including M)
///   - SUM(overspending of the months before M)
///   - held(M), the part of the budgets of later months that the money
///   arriving in those months does not cover
///   (see [calculateHeldForLaterMonths]).
/// * Credit cards: every budget credit card has a payment category
///   (`CardPayments`). Card spending moves the part its category can cover
///   to the payment category; the rest is credit overspending, reset at
///   the end of the month without a charge (card debt). Payments to the
///   card are payment-category activity. See [_rollTo] and [_CardMonth].
/// * Invariant: SUM(available(M)) + TBB(M) + held(M)
///   + credit overspending(M)
///   == SUM(balances of the on-budget accounts that are not budget cards,
///      up to end of M) + card income(M) (positive card starting balances
///      and uncategorised card inflows). Without cards: SUM(available) +
///   TBB + held == SUM(on-budget balances). See docs/BUDGETING_RULES.md,
///   "The budget identity".
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
  ///       the month, see [_startingBalances]; a budget credit card's
  ///       negative starting balance, existing debt, counts as 0)
  ///     + SUM(uncategorised, non-split-parent rows of on-budget accounts up
  ///       to the end of the month, both signs, transfer legs only when the
  ///       other account is off-budget; uncategorised outflows of a budget
  ///       credit card are left out: unfunded card debt, not spending of
  ///       To Be Budgeted)
  ///     - SUM(budgeted up to and including the month)
  ///     - SUM(cash overspending of the months before it: a negative
  ///       category balance is not carried into the next month's category
  ///       but taken out of To Be Budgeted, see [_rollTo]; credit
  ///       overspending is not charged, it is card debt)
  ///     - the money held for later months ([calculateHeldForLaterMonths]):
  ///       what is budgeted in the months after it beyond the money that
  ///       arrives in those months.
  ///
  /// Uncategorised outflows (and reconciliation adjustments) therefore
  /// reduce TBB, starting balances are budgetable, transfers between
  /// on-budget accounts do not change it, and off-budget (tracking)
  /// accounts only matter when money moves to or from them.
  Future<int> calculateTBB(DateTime targetMonth) async {
    final nextMonthStart = CalendarDate.endOfMonthUtc(targetMonth);

    final starting = await _startingBalances();
    final readyToAssign = await _transactionRepository.getReadyToAssignSum(
      CalendarDate.beginningOfTime,
      nextMonthStart,
    );
    final roll = await _rollTo(targetMonth);
    final held = await _heldForLaterMonths(targetMonth, starting);

    return starting.through(targetMonth) +
        readyToAssign -
        roll.budgetedThrough -
        roll.overspentBefore -
        held;
  }

  /// Money of [month]'s To Be Budgeted that the months after it need
  /// (minor units, never negative): budgets of a later month are paid
  /// first from the money arriving after [month] (positive rows flowing
  /// into To Be Budgeted, and the positive starting balances of accounts
  /// that start then), and only the rest is taken from [month]:
  ///
  /// `held(M) = max(0, max over F in (M, L] of
  ///     SUM(budgeted in (M, F]) - SUM(arriving in (M, F]))`
  ///
  /// where L is the last month with a budget. Outflows and overspending of
  /// a later month are charged to that month, never to [month]. With no
  /// budget after [month] this is 0.
  Future<int> calculateHeldForLaterMonths(DateTime month) async =>
      _heldForLaterMonths(month, await _startingBalances());

  Future<int> _heldForLaterMonths(
    DateTime month,
    _StartingBalances starting,
  ) async {
    final budgeted = await _budgetRepository.getBudgetedByMonthAfter(
      CalendarDate.monthKey(month),
    );
    final months = [
      for (final MapEntry(:key, :value) in budgeted.entries)
        if (value != 0) key,
    ]..sort();
    if (months.isEmpty) {
      return 0;
    }
    final last = CalendarDate.parseMonthKey(months.last);
    final arriving = await _budgetRepository.getMonthlyReadyToAssignInflows(
      CalendarDate.endOfMonthUtc(month),
      CalendarDate.endOfMonthUtc(last),
    );
    var short = 0;
    var held = 0;
    final count = _monthsDifference(month, last);
    for (var i = 1; i <= count; i++) {
      final key = CalendarDate.monthKey(
        DateTime.utc(month.year, month.month + i, 1),
      );
      short +=
          (budgeted[key] ?? 0) -
          (arriving[key] ?? 0) -
          (starting.positiveByMonth[key] ?? 0);
      held = math.max(held, short);
    }
    return held;
  }

  /// The starting balances of the on-budget accounts by start month. An
  /// account exists from the earlier of the month it was created in and
  /// the month of its first transaction (imported or backdated history),
  /// so a month before the account shows nothing of it; an account without
  /// a creation time always counts.
  ///
  /// The creation month is the one on the user's calendar (the local day
  /// of `created_at`, like every other month boundary, see
  /// [CalendarDate.today]), not the UTC month of the instant: an account
  /// created on the evening of the 31st west of UTC belongs to that month.
  Future<_StartingBalances> _startingBalances() async {
    final accounts = await _accountRepository.getAllAccounts();
    final firstDates = await _budgetRepository.getFirstTransactionDates();
    var always = 0;
    final byMonth = <String, int>{};
    final positiveByMonth = <String, int>{};
    final startMonth = <String, String?>{};
    for (final account in accounts) {
      if (!account.onBudget) {
        continue;
      }
      final createdAt = account.createdAt;
      final created = createdAt == null
          ? null
          : CalendarDate.today(now: createdAt);
      final first = firstDates[account.id]?.toUtc();
      final start = created == null
          ? null
          : (first != null && first.isBefore(created) ? first : created);
      startMonth[account.id] = start == null
          ? null
          : CalendarDate.monthKey(start);
      // Existing card debt is not budgeted money: the card's payment
      // category shows it as still to cover instead.
      final balance =
          CardPayments.isBudgetCard(account) && account.startingBalance < 0
          ? 0
          : account.startingBalance;
      if (start == null) {
        always += balance;
      } else {
        final key = CalendarDate.monthKey(start);
        byMonth[key] = (byMonth[key] ?? 0) + balance;
        if (balance > 0) {
          positiveByMonth[key] = (positiveByMonth[key] ?? 0) + balance;
        }
      }
    }
    return _StartingBalances(always, byMonth, positiveByMonth, startMonth);
  }

  /// Rolls every category (or only [categoryId]) forward month by month
  /// from the first month with a budget or activity up to [month]:
  ///
  /// `available(M) = max(0, available(M - 1)) + budgeted(M) + activity(M)`
  ///
  /// A negative balance at the end of a month does not reduce the category
  /// in the next month. Its cash part (cash overspending) is counted in
  /// [_Rollover.overspentBefore] and taken out of To Be Budgeted there; its
  /// credit part (card spending the category could not cover) is counted
  /// in [_Rollover.creditOverspentBefore] and is not charged: it is card
  /// debt the payment category does not cover.
  ///
  /// Credit cards (docs/BUDGETING_RULES.md, "Credit cards"): a (month,
  /// category) with card rows, the payment categories and the card legs of
  /// transfers within the budget are processed row by row in a fixed order
  /// (date, `created_at`, id), see [_CardMonth]; every other (month,
  /// category) adds its summed activity. Three grouped queries and one
  /// query of individual card-related rows, whatever the number of months.
  Future<_Rollover> _rollTo(DateTime month, {String? categoryId}) async {
    final monthKey = CalendarDate.monthKey(month);
    final end = CalendarDate.endOfMonthUtc(month);
    final accounts = await _accountRepository.getAllAccounts();
    final paymentOf = <String, String>{
      for (final a in accounts)
        if (CardPayments.isBudgetCard(a)) a.id: CardPayments.categoryId(a.id),
    };
    final paymentIds = paymentOf.values.toSet();
    // A payment category depends on the spending of every category; any
    // other category only on its own rows.
    final only = categoryId != null && !paymentIds.contains(categoryId)
        ? categoryId
        : null;

    final budgets = await _budgetRepository.getBudgetsUpToMonth(
      monthKey,
      categoryId: only,
    );
    final activity = await _budgetRepository.getMonthlyCategoryActivity(
      end,
      categoryId: only,
    );
    final cardRows = paymentOf.isEmpty
        ? const <CardLedgerRow>[]
        : await _budgetRepository.getCardLedgerRows(
            end,
            cardIds: paymentOf.keys.toSet(),
            paymentCategoryIds: paymentIds,
            categoryId: only,
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

    // Rows processed one by one replace the summed activity of their
    // (month, category).
    final rowsByMonth = <String, List<CardLedgerRow>>{};
    final processed = <String, Set<String>>{};
    for (final row in cardRows) {
      final key = CalendarDate.monthKey(row.date);
      rowsByMonth.putIfAbsent(key, () => []).add(row);
      if (row.categoryId case final c?) {
        processed.putIfAbsent(key, () => {}).add(c);
      }
    }

    final months = {
      ...budgetedByMonth.keys,
      ...activity.keys,
      ...rowsByMonth.keys,
    }.where((m) => m.compareTo(monthKey) <= 0).toList()..sort();
    final available = <String, int>{};
    var overspentBefore = 0;
    var creditOverspentBefore = 0;
    var credit = _CardMonth(available, paymentOf);
    if (months.isEmpty) {
      return _Rollover(
        available: available,
        overspentBefore: 0,
        creditOverspentBefore: 0,
        budgetedThrough: budgetedThrough,
        creditOverspent: const {},
        paymentActivity: const {},
      );
    }
    final first = CalendarDate.parseMonthKey(months.first);
    final count = _monthsDifference(first, month) + 1;
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        // Month boundary: last month's overspending leaves the category;
        // its cash part is charged to To Be Budgeted, its credit part is
        // card debt.
        for (final entry in available.entries.toList()) {
          if (entry.value < 0) {
            final creditPart = math.min(
              credit.creditOverspent(entry.key),
              -entry.value,
            );
            creditOverspentBefore += creditPart;
            overspentBefore += -entry.value - creditPart;
            available[entry.key] = 0;
          }
        }
        credit = _CardMonth(available, paymentOf);
      }
      final key = CalendarDate.monthKey(
        DateTime.utc(first.year, first.month + i, 1),
      );
      for (final MapEntry(key: id, value: amount)
          in (budgetedByMonth[key] ?? const <String, int>{}).entries) {
        available[id] = (available[id] ?? 0) + amount;
      }
      final skip = processed[key] ?? const <String>{};
      for (final MapEntry(key: id, value: amount)
          in (activity[key] ?? const <String, int>{}).entries) {
        if (!skip.contains(id)) {
          available[id] = (available[id] ?? 0) + amount;
        }
      }
      final rows = rowsByMonth[key];
      if (rows != null) {
        rows.sort(CardLedgerRow.compare);
        rows.forEach(credit.apply);
      }
    }
    return _Rollover(
      available: available,
      overspentBefore: overspentBefore,
      creditOverspentBefore: creditOverspentBefore,
      budgetedThrough: budgetedThrough,
      creditOverspent: {
        for (final id in available.keys)
          if (credit.creditOverspent(id) > 0) id: credit.creditOverspent(id),
      },
      paymentActivity: credit.paymentActivity,
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

  /// Total spending (negative) for [month], by the one definition of
  /// spending the reports use (see `Spending` and BUDGETING_RULES.md):
  /// on-budget, no transfer legs, categorised rows netted per category and
  /// clamped at 0, uncategorised outflows included; a split counts through
  /// its children, never twice.
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

  /// Gets the budgeted amount in the previous month, or 0 when it was not
  /// positive (a negative budget, left by moving money out of a category,
  /// is not copied; same rule as [budgetsOfPreviousMonth]).
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
    return math.max(0, budget?.budgeted ?? 0);
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

  /// Ids of the categories that take part in month operations (copy,
  /// templates, reset, fill): every category that exists and is not
  /// hidden.
  Future<Set<String>> _visibleCategoryIds() async => {
    for (final c in await _categoryRepository.getAllCategories())
      if (!c.isHidden) c.id,
  };

  /// Stores the positive budgets of the visible categories of [month] as a
  /// template.
  Future<void> saveBudgetTemplate(String name, DateTime month) async {
    final monthString = CalendarDate.monthKey(month);
    final budgets = await _budgetRepository.getBudgetsForMonth(monthString);
    final visible = await _visibleCategoryIds();

    final Map<String, int> data = {};
    for (final budget in budgets) {
      if (budget.categoryId != null &&
          budget.budgeted > 0 &&
          visible.contains(budget.categoryId)) {
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

  /// Writes the template's amounts into [month] (a merge: categories not
  /// in the template keep their amounts). Entries of hidden or deleted
  /// categories are skipped. Returns what changed, for undo.
  Future<BudgetMonthChange> applyBudgetTemplate(
    String templateId,
    DateTime month,
  ) async {
    final template = await _budgetTemplateRepository.getTemplateById(
      templateId,
    );
    if (template == null) {
      return BudgetMonthChange.none(month);
    }
    final visible = await _visibleCategoryIds();
    return _writeMonth(month, {
      for (final MapEntry(key: id, value: amount) in template.data.entries)
        if (visible.contains(id)) id: amount,
    });
  }

  Future<List<BudgetTemplate>> getAllTemplates() {
    return _budgetTemplateRepository.getAllTemplates();
  }

  Future<void> deleteTemplate(String id) {
    return _budgetTemplateRepository.deleteTemplate(id);
  }

  // --- Bulk Operations ---

  /// Sets the visible categories budgeted in the month before [month] to
  /// the same amounts in [month] (other categories keep theirs). Returns
  /// what changed, for undo.
  Future<BudgetMonthChange> copyBudgetFromPreviousMonth(DateTime month) async {
    final previous = await budgetsOfPreviousMonth(month);
    final visible = await _visibleCategoryIds();
    return _writeMonth(month, {
      for (final MapEntry(key: id, value: amount) in previous.entries)
        if (visible.contains(id)) id: amount,
    });
  }

  /// Sets the budgets of [month] to [amounts] (category -> amount) in one
  /// unit of work, e.g. to undo or redo a month operation. Categories that
  /// no longer exist are skipped, so one deleted category does not stop
  /// the rest from being restored. Returns what changed.
  Future<BudgetMonthChange> setCategoryBudgetedAmounts(
    Map<String, int> amounts,
    DateTime month,
  ) async {
    final existing = {
      for (final c in await _categoryRepository.getAllCategories()) c.id,
    };
    return _writeMonth(month, {
      for (final MapEntry(key: id, value: amount) in amounts.entries)
        if (existing.contains(id)) id: amount,
    });
  }

  /// Writes [amounts] into [month] in one unit of work, touching only the
  /// categories whose amount differs, and returns the old and new amounts
  /// of those.
  Future<BudgetMonthChange> _writeMonth(
    DateTime month,
    Map<String, int> amounts,
  ) async {
    final current = {
      for (final b in await _budgetRepository.getBudgetsForMonth(
        CalendarDate.monthKey(month),
      ))
        if (b.categoryId != null) b.categoryId!: b.budgeted,
    };
    final before = <String, int>{};
    final after = <String, int>{};
    for (final MapEntry(key: id, value: amount) in amounts.entries) {
      final old = current[id] ?? 0;
      if (old != amount) {
        before[id] = old;
        after[id] = amount;
      }
    }
    if (after.isNotEmpty) {
      await _unitOfWork.run(() async {
        for (final MapEntry(key: id, value: amount) in after.entries) {
          await _writeBudget(id, month, (_) => amount);
        }
      });
    }
    return BudgetMonthChange(month: month, before: before, after: after);
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

  /// Releases what the payment category of card [accountId] holds in
  /// [month] to To Be Budgeted ([releaseFromCategory] with its available
  /// amount), after the card was closed, taken off the budget or changed to
  /// another account type. What cannot be released that way (money moved
  /// there by card spending rather than budgeted) stays in the hidden
  /// category, which the budget screen then lists under "Hidden
  /// categories". Returns the amount released.
  Future<int> releasePaymentCategory(String accountId, DateTime month) async {
    final categoryId = CardPayments.categoryId(accountId);
    final available = await calculateCategoryAvailable(categoryId, month);
    return releaseFromCategory(categoryId, available, month);
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
    final visible = await _visibleCategoryIds();
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

  /// Sets every visible category of [month] to zero (hidden categories
  /// keep their amounts, like in every month operation). Returns what
  /// changed, for undo.
  Future<BudgetMonthChange> resetBudget(DateTime month) async {
    final budgets = await _budgetRepository.getBudgetsForMonth(
      CalendarDate.monthKey(month),
    );
    final visible = await _visibleCategoryIds();
    return _writeMonth(month, {
      for (final b in budgets)
        if (b.categoryId != null &&
            b.budgeted != 0 &&
            visible.contains(b.categoryId))
          b.categoryId!: 0,
    });
  }

  int _monthsDifference(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + to.month - from.month;
  }

  /// Calculates activity and available amounts for all categories in a specific [month].
  ///
  /// Returns a map where the key is categoryId and the value is another
  /// map with 'activity', 'available' and 'creditOverspent' keys:
  ///
  /// * activity: the category's transactions in the month; for a payment
  ///   category the money moved in by card spending, minus refunds moved
  ///   back and payments to the card ([_Rollover.paymentActivity]);
  /// * creditOverspent: the part of a negative available that is credit
  ///   overspending (card spending the category could not cover), 0 when
  ///   it is cash overspending or not overspent.
  ///
  /// Grouped queries (activity in the month, activity per month, budgets
  /// up to the month), the card rows and one in-memory rollover
  /// ([_rollTo]).
  Future<Map<String, Map<String, int>>> calculateBatchCategoryPerformance(
    DateTime month,
  ) async {
    final startOfMonth = CalendarDate.startOfMonthUtc(month);
    final endOfMonth = CalendarDate.endOfMonthUtc(month); // exclusive

    final currentActivityMap = await _transactionRepository
        .getCategoryActivitySums(startOfMonth, endOfMonth);
    final roll = await _rollTo(month);

    final Map<String, Map<String, int>> result = {};
    for (final catId in {
      ...currentActivityMap.keys,
      ...roll.available.keys,
      ...roll.paymentActivity.keys,
    }) {
      result[catId] = {
        'activity':
            (currentActivityMap[catId] ?? 0) +
            (roll.paymentActivity[catId] ?? 0),
        'available': roll.available[catId] ?? 0,
        'creditOverspent': roll.creditOverspent[catId] ?? 0,
      };
    }
    return result;
  }

  /// The payment category of every budget credit card in [month]: account
  /// id -> [CardPaymentStatus] (what it holds, the card balance at the end
  /// of the month, what is still missing to pay the card in full).
  Future<Map<String, CardPaymentStatus>> calculateCardPaymentStatuses(
    DateTime month,
  ) async {
    final accounts = [
      for (final a in await _accountRepository.getAllAccounts())
        if (CardPayments.isBudgetCard(a)) a,
    ];
    if (accounts.isEmpty) {
      return const {};
    }
    final roll = await _rollTo(month);
    final starting = await _startingBalances();
    final changes = await _budgetRepository.getBalanceChangesBefore(
      CalendarDate.endOfMonthUtc(month),
    );
    return {
      for (final a in accounts)
        a.id: CardPaymentStatus(
          available: roll.available[CardPayments.categoryId(a.id)] ?? 0,
          balance:
              (starting.existsBy(a.id, month) ? a.startingBalance : 0) +
              (changes[a.id] ?? 0),
        ),
    };
  }

  /// [calculateCardPaymentStatuses] of one card; null when [accountId] is
  /// not a budget credit card.
  Future<CardPaymentStatus?> calculateCardPaymentStatus(
    String accountId,
    DateTime month,
  ) async => (await calculateCardPaymentStatuses(month))[accountId];

  /// Total credit overspending (positive minor units) shown in [month]:
  /// the card spending the categories could not cover, which resets at the
  /// end of the month without a charge to To Be Budgeted (it is card
  /// debt). A term of the budget identity, see docs/BUDGETING_RULES.md.
  Future<int> calculateCreditOverspending(DateTime month) async {
    final roll = await _rollTo(month);
    return roll.creditOverspent.values.fold<int>(0, (a, b) => a + b);
  }

  /// Adds what card [accountId]'s payment category is still missing in
  /// [month] ([CardPaymentStatus.missing]) to its budget, so the card can
  /// be paid in full. Returns the amount added (0 when nothing is missing).
  Future<int> coverCardBalance(String accountId, DateTime month) async {
    final status = await calculateCardPaymentStatus(accountId, month);
    final missing = status?.missing ?? 0;
    if (missing > 0) {
      await addToCategoryBudget(
        CardPayments.categoryId(accountId),
        missing,
        month,
      );
    }
    return missing;
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

/// The payment category of a budget credit card in a month (minor units).
class CardPaymentStatus {
  /// What the payment category holds at the end of the month.
  final int available;

  /// The card balance at the end of the month (negative: debt).
  final int balance;

  const CardPaymentStatus({required this.available, required this.balance});

  /// The card's debt (0 when it has no debt).
  int get debt => balance < 0 ? -balance : 0;

  /// What the payment category still needs to pay the card in full:
  /// `max(0, -balance - available)`.
  int get missing => math.max(0, debt - available);

  @override
  bool operator ==(Object other) =>
      other is CardPaymentStatus &&
      other.available == available &&
      other.balance == balance;

  @override
  int get hashCode => Object.hash(available, balance);

  @override
  String toString() =>
      'CardPaymentStatus(available: $available, balance: $balance)';
}

/// What a month operation (copy from the month before, apply a template,
/// reset) changed in [month]: the amounts before and after, for the
/// categories whose amount changed. Undo writes [before], redo [after].
class BudgetMonthChange {
  final DateTime month;
  final Map<String, int> before;
  final Map<String, int> after;

  const BudgetMonthChange({
    required this.month,
    required this.before,
    required this.after,
  });

  const BudgetMonthChange.none(this.month)
    : before = const {},
      after = const {};

  bool get isEmpty => after.isEmpty;
}

/// Result of [BudgetingService._rollTo].
class _Rollover {
  /// categoryId -> available at the end of the month (categories with
  /// neither budgets nor activity are absent).
  final Map<String, int> available;

  /// Cash overspending (positive minor units) of all months before the
  /// month, charged to its To Be Budgeted.
  final int overspentBefore;

  /// Credit overspending (positive minor units) of all months before the
  /// month: card spending no category covered, reset without a charge.
  final int creditOverspentBefore;

  /// Everything budgeted up to and including the month.
  final int budgetedThrough;

  /// categoryId -> the credit part (positive) of its negative available at
  /// the end of the month; categories without credit overspending are
  /// absent.
  final Map<String, int> creditOverspent;

  /// Payment categoryId -> its activity in the month: spending moved in
  /// from the spending categories, refunds moved back, payments and cash
  /// advances (minor units, signed).
  final Map<String, int> paymentActivity;

  const _Rollover({
    required this.available,
    required this.overspentBefore,
    required this.creditOverspentBefore,
    required this.budgetedThrough,
    required this.creditOverspent,
    required this.paymentActivity,
  });
}

/// The credit-card rules of one month, applied row by row in the fixed
/// order (see docs/BUDGETING_RULES.md, "Credit cards", and
/// docs/ALGORITHMS.md). Works on the rollover's [available] map, which
/// already holds the month's starting balances and budgets: money
/// assigned during the month counts from its first day, as in YNAB.
///
/// * Card spending `s` in category X moves `f = min(s, max(0, X))` to the
///   card's payment category; X goes down by `s`, and `s - f` is credit
///   overspending of X for that card.
/// * A card refund `r` in X first cancels X's credit overspending for that
///   card (the debt it was never funded for shrinks by itself), the rest
///   is taken back from the payment category; X goes up by `r`.
/// * Whenever X goes up (a refund on any account), credit overspending
///   that X's balance no longer shows is covered: that money moves to the
///   card's payment category, oldest first. So X's credit overspending is
///   never more than its negative balance.
/// * Cash rows in X change X only.
/// * A transfer between a card and a non-card budget account changes the
///   payment category by minus the card leg: a payment (`+p` on the card)
///   takes `p` out of it (it can go negative: cash overspending), a cash
///   advance (`-a`) puts `a` in.
/// * A balance transfer between two cards moves what the paying-off
///   card's payment category holds, at most the amount, to the other
///   card's payment category: the funding follows the debt, and debt that
///   was not funded stays unfunded without touching To Be Budgeted.
class _CardMonth {
  _CardMonth(this.available, this.paymentOf);

  final Map<String, int> available;

  /// Budget card account id -> its payment category id.
  final Map<String, String> paymentOf;

  /// categoryId -> unfunded card spending (card account id, amount), oldest
  /// first.
  final Map<String, List<_Unfunded>> _unfunded = {};

  final Map<String, int> paymentActivity = {};

  int creditOverspent(String categoryId) =>
      (_unfunded[categoryId] ?? const <_Unfunded>[]).fold(
        0,
        (sum, u) => sum + u.amount,
      );

  void _add(String categoryId, int amount) =>
      available[categoryId] = (available[categoryId] ?? 0) + amount;

  void _toPayment(String paymentId, int amount) {
    if (amount == 0) {
      return;
    }
    _add(paymentId, amount);
    paymentActivity[paymentId] = (paymentActivity[paymentId] ?? 0) + amount;
  }

  void apply(CardLedgerRow row) {
    final payment = paymentOf[row.accountId];
    if (row.isBudgetTransfer) {
      if (payment == null) {
        return;
      }
      final other = paymentOf[row.transferAccountId];
      if (other == null) {
        // Payment (+) or cash advance (-) between the card and a cash
        // account of the budget.
        _toPayment(payment, -row.amount);
      } else if (row.amount > 0) {
        // Balance transfer: this card's debt went down, the other's up.
        final move = math.min(row.amount, math.max(0, available[payment] ?? 0));
        _toPayment(payment, -move);
        _toPayment(other, move);
      }
      return;
    }
    final category = row.categoryId!;
    final amount = row.amount;
    if (payment == null) {
      _add(category, amount);
      if (amount > 0) {
        _cover(category);
      }
      return;
    }
    if (amount < 0) {
      final spent = -amount;
      final funded = math.min(spent, math.max(0, available[category] ?? 0));
      _add(category, amount);
      _toPayment(payment, funded);
      if (spent > funded) {
        _unfunded
            .putIfAbsent(category, () => [])
            .add(_Unfunded(row.accountId, spent - funded));
      }
      return;
    }
    // A refund on the card.
    var cancel = amount;
    final list = _unfunded[category];
    if (list != null) {
      for (final u in list) {
        if (cancel == 0) {
          break;
        }
        if (u.cardId == row.accountId) {
          final take = math.min(cancel, u.amount);
          u.amount -= take;
          cancel -= take;
        }
      }
      list.removeWhere((u) => u.amount == 0);
    }
    _add(category, amount);
    _toPayment(payment, -cancel);
    _cover(category);
  }

  /// Covers credit overspending of [category] that its balance no longer
  /// shows, oldest first, by moving that money to the cards' payment
  /// categories.
  void _cover(String category) {
    final list = _unfunded[category];
    if (list == null || list.isEmpty) {
      return;
    }
    final shown = available[category] ?? 0;
    var excess = creditOverspent(category) - (shown < 0 ? -shown : 0);
    for (final u in list) {
      if (excess <= 0) {
        break;
      }
      final take = math.min(excess, u.amount);
      u.amount -= take;
      excess -= take;
      _toPayment(paymentOf[u.cardId]!, take);
    }
    list.removeWhere((u) => u.amount == 0);
  }
}

class _Unfunded {
  _Unfunded(this.cardId, this.amount);

  final String cardId;
  int amount;
}

/// The starting balances of the on-budget accounts: [always] (accounts
/// without a creation time) and per start month (`yyyy-MM`).
class _StartingBalances {
  final int always;
  final Map<String, int> byMonth;

  /// Per start month, the positive starting balances only: money that
  /// arrives in To Be Budgeted that month (a negative one, existing debt,
  /// is charged to its own month like an outflow).
  final Map<String, int> positiveByMonth;

  /// On-budget account id -> its start month (`yyyy-MM`), null for an
  /// account without a creation time (it always counts).
  final Map<String, String?> startMonth;

  _StartingBalances(
    this.always,
    this.byMonth,
    this.positiveByMonth,
    this.startMonth,
  );

  /// Whether on-budget account [accountId] exists by the end of [month].
  bool existsBy(String accountId, DateTime month) {
    if (!startMonth.containsKey(accountId)) {
      return false;
    }
    final start = startMonth[accountId];
    return start == null || start.compareTo(CalendarDate.monthKey(month)) <= 0;
  }

  /// Sum of the starting balances of the accounts that exist by the end of
  /// [month].
  int through(DateTime month) {
    final key = CalendarDate.monthKey(month);
    var total = always;
    for (final MapEntry(key: start, :value) in byMonth.entries) {
      if (start.compareTo(key) <= 0) {
        total += value;
      }
    }
    return total;
  }
}
