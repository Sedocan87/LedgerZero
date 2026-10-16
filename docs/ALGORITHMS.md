# Budget Algorithms

How the budget numbers are computed in code. The rules themselves (what
counts towards what, the invariant, credit cards) are in
[BUDGETING_RULES.md](BUDGETING_RULES.md); this page maps them to the
implementation.

All amounts are `int` minor units. Months are `yyyy-MM` keys
(`CalendarDate.monthKey`); "end of M" is the exclusive bound
`CalendarDate.endOfMonthUtc(M)` (first day of the next month, UTC).
The code is in `lib/domain/services/budgeting_service.dart` (`BudgetingService`)
and the aggregate queries in `lib/data/database/daos/transactions_dao.dart`.

## To Be Budgeted (`calculateTBB`)

```
TBB(M) = AccountRepository.getTotalStartingBalance()
       + TransactionRepository.getReadyToAssignSum(beginningOfTime, endOfMonth(M))
       - BudgetRepository.getTotalBudgetedByMonthRange(M)   // all budget rows with month <= M
```

`getReadyToAssignSum` sums rows that are not deleted, have no category, are
not a transfer leg (`transfer_account_id IS NULL`) and are not a split
parent (no non-deleted child row). Both signs count.

## Activity and available

* `calculateCategoryActivity(c, M)`: `getCategoryActivitySum(c, start(M), end(M))`,
  the sum of non-deleted rows carrying category `c` (split lines included).
* `calculateCategoryAvailable(c, M)`: budgeted for `c` in all months `<= M`
  plus activity of `c` from `beginningOfTime` to `end(M)`. Rollover of
  positive balances and overspending follows from summing all history.
* The budget screen uses the batch variant
  `calculateBatchCategoryPerformance(M)`: three grouped queries
  (activity in M, activity up to end of M, budgeted up to M) combined per
  category, instead of one query per category.

## Writing budgets

`setCategoryBudgetedAmount`, `moveMoney`, templates, copy-from-previous and
reset all go through one helper that sets `budgeted = f(current)` for a
category and month inside a unit of work:

* If the row exists, it is updated.
* Otherwise it is created with the deterministic id
  `DeterministicId.budgetForKey(categoryId, "yyyy-MM")` (UUIDv5 of
  `budget:<categoryId>:<yyyy-MM>`), so two devices creating the same month's
  row produce the same id.
* If the insert fails because the row appeared meanwhile, it re-reads and
  updates.

`moveMoney(from, to, amount, M)` subtracts from one row and adds to the other
in one unit of work, so total budgeted (and TBB) never changes.

## Goal targets (`calculateGoalTarget`, `calculateBatchGoalTargets`)

Goals cannot be set in the app yet (no goals UI; planned, see
ROADMAP.md). Categories have `goalType`, `targetAmount` and `targetDate`
fields for it, but nothing in the app writes them, so these paths only run
in tests today.

"Prior available" is the category's available amount at the end of the
previous month (M - 1). The returned target is what to budget in M.

| Goal type | Target for month M |
| --- | --- |
| none / no target amount | 0 |
| `monthlyFunding` | `targetAmount` |
| `targetBalance` | `max(0, targetAmount - priorAvailable)` |
| `targetBalanceByDate` | `needed = targetAmount - priorAvailable`; 0 if `needed <= 0`, else `Money.divideRounded(needed, monthsRemaining)` |

`monthsRemaining = (targetYear - Y) * 12 + (targetMonth - Mo) + 1`, at least
1 (a target date in the past or in M counts as one month). A
`targetBalanceByDate` goal without a target date returns 0.

`calculateFundedPercentage` = budgeted in M / target (1.0 when the target is
0); it is a display ratio only.

The budget row would show an "underfunded" icon when the goal target is
greater than 0 and the budgeted amount is below it; without goals it never
does.

## Auto-assign (`autoAssign`)

Sets the month's budgeted amount to:

| Rule | Amount |
| --- | --- |
| `underfunded` | the goal target above |
| `averageSpent` | `abs(divideRounded(activity of the 3 previous months, 3))` |
| `lastMonthSpent` | `abs(activity of M - 1)` |
| `lastMonthBudgeted` | budgeted in M - 1 (0 if none) |

The budget row's long-press menu offers `lastMonthBudgeted`,
`lastMonthSpent` and `averageSpent`. `underfunded` exists in the service
for the future goals feature but is hidden from the UI, because goals
cannot be set yet.

## Month-level operations

* `copyBudgetFromPreviousMonth(M)`: copies every positive budget of M - 1
  into M (overwriting M's value for those categories).
* `resetBudget(M)`: sets every non-zero budget of M to 0.
* `saveBudgetTemplate(name, M)`: stores the positive budgets of M as a
  template; `applyBudgetTemplate(id, M)` writes them into M.
