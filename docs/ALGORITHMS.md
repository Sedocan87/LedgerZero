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
TBB(M) = startingBalancesThrough(M)
       + TransactionRepository.getReadyToAssignSum(beginningOfTime, endOfMonth(M))
       - budgeted through M            // rollover: every budget row with month <= M
       - BudgetRepository.getTotalBudgetedAfterMonth(M)   // rows with month > M
       - overspending before M         // rollover, see below
```

* `startingBalancesThrough(M)`: the starting balances of the on-budget
  accounts whose start month is `<= M`. The start month is the earlier of
  `accounts.created_at` and the account's first non-deleted transaction
  (`BudgetRepository.getFirstTransactionDates`, one grouped query); an
  account without `created_at` always counts.
* `getReadyToAssignSum` sums rows that are not deleted, have no category,
  belong to an on-budget account, are not a split parent (no non-deleted
  child row) and are not a transfer leg unless the other account is
  off-budget. Both signs count.
* Budgets of every month count: money assigned to a later month is not
  available in M (`getTotalBudgetedAfterMonth`).
* Overspending before M is what the rollover charges to TBB.

## Rollover (`_rollTo`), activity and available

Available is computed month by month, in memory, from the first month that
has a budget row or category activity up to M:

```
available(c, m) = max(0, available(c, m - 1)) + budgeted(c, m) + activity(c, m)
overspending before M = SUM over m < M, c of max(0, -available(c, m))
```

Two grouped queries feed it, whatever the number of months and categories:
`BudgetRepository.getBudgetsUpToMonth(M)` (every budget row with
`month <= M`) and `BudgetRepository.getMonthlyCategoryActivity(end(M))`
(`yyyy-MM` -> category -> signed sum of the categorised activity rows:
non-deleted, on-budget account, split lines included, transfer legs only
when the transfer crosses the budget boundary). Both live in `BudgetsDao`;
the activity filter mirrors `TransactionsDao.getCategoryActivitySums`.

* `calculateCategoryActivity(c, M)`: `getCategoryActivitySum(c, start(M), end(M))`.
* `calculateCategoryAvailable(c, M)`: the rollover restricted to `c`.
* `calculateBatchCategoryPerformance(M)` (budget screen): activity in M
  (one grouped query) plus the rollover for all categories.
* `calculateTBB(M)` uses the same rollover for "budgeted through M" and
  "overspending before M", so the invariant in BUDGETING_RULES.md holds by
  construction.

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
| `averageSpent` | `abs(divideRounded(activity of the 3 previous months, number of those months with activity, at least 1))` |
| `lastMonthSpent` | `abs(activity of M - 1)` |
| `lastMonthBudgeted` | budgeted in M - 1 (0 if none) |

The budget row's long-press menu offers `lastMonthBudgeted`,
`lastMonthSpent` and `averageSpent`. `underfunded` exists in the service
for the future goals feature but is hidden from the UI, because goals
cannot be set yet.

## Month-level operations

All go through one helper that reads the month's rows, keeps only the
categories whose amount would change, writes those in one unit of work and
returns a `BudgetMonthChange` (category -> amount before and after) for
undo. Hidden and deleted categories are skipped (`_visibleCategoryIds`).

* `copyBudgetFromPreviousMonth(M)`: every positive budget of M - 1 into M
  (overwriting M's value for those categories, leaving the others).
* `applyBudgetTemplate(id, M)`: the template's entries into M (a merge).
* `resetBudget(M)`: every non-zero budget of M to 0.
* `saveBudgetTemplate(name, M)`: stores the positive budgets of M.
* `setCategoryBudgetedAmounts(amounts, M)`: writes a map of amounts (undo
  and redo of the above); categories that no longer exist are skipped.
