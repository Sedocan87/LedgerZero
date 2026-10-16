# Budget Screen Interactions

What the user can do on the Budget tab (`BudgetScreen`,
`lib/presentation/screens/budget/`) and which code runs. For how the numbers
are defined see [BUDGETING_RULES.md](BUDGETING_RULES.md); for how they are
computed see [ALGORITHMS.md](ALGORITHMS.md).

## Layout

* Month selector (previous/next month); the month is held in
  `selectedBudgetMonthProvider`.
* To Be Budgeted banner (`ToBeBudgetedBanner`), from `tbbProvider(month)`.
* Category groups and rows (`BudgetGroupRow`, `BudgetCategoryRow`) from
  `budgetViewModelProvider`.
* App bar: search (filters categories by name), view mode toggle, manage
  categories (`/budget/categories`), and a menu with save as template, apply
  template, copy from previous month and reset budget.

View modes (`BudgetViewMode`):

* **standard**: Budgeted, Activity and Available columns.
* **comparison**: a "spent of budgeted" progress bar per category.

## Assigning money to a category

1. In standard mode, tap the Budgeted cell. A calculator bottom sheet
   (`BudgetCalculator`) opens with the current value; it accepts an amount
   or an arithmetic expression.
2. On submit, `BudgetingService.setCategoryBudgetedAmount` writes the
   month's budget row (created with its deterministic id if missing).
3. A `BudgetChangeAction` is pushed on the undo stack and a snackbar offers
   Undo.

## Quick actions (long-press a category row)

* **Budget previous month**: auto-assign `lastMonthBudgeted`.
* **Budget last month's spending**: auto-assign `lastMonthSpent` (what the
  category spent in the previous month).
* **Average spent**: auto-assign `averageSpent` (3 previous months).
* **Zero out**: sets the budget to 0.
* **Move money**: opens `MoveMoneyModal` with this category as source.

The first four record an undo action like a manual edit. The goal-based
`underfunded` rule is not offered: goals cannot be set in the app yet.

## Moving money

`MoveMoneyModal` asks for source category, target category and a positive
amount; source and target must differ. `BudgetingService.moveMoney`
decrements the source's and increments the target's budget for the selected
month in one unit of work, so TBB does not change. The source may go
negative. A `MoveMoneyAction` is pushed on the undo stack and a snackbar
("Money moved") offers Undo. Undo moves the same amount back and redo moves
it again, each as one `moveMoney` call, so both categories always change
together.

## Drag from To Be Budgeted

When TBB is positive, long-press the TBB amount and drop it on a category
row. A dialog asks how much to assign, pre-filled with the whole TBB. The
entered amount is added to the category's current budget (with undo).

## Viewing activity

Tap the Activity cell. A filtered transaction list
(`filtered-transactions` route) opens with the category and the selected
month as a fixed filter; it does not change the Transactions tab's own
filter.

## Goals (not available yet)

Goals cannot be set in the app yet: the category form has no goal fields
and the YNAB import does not import goals (a goals UI is planned, see
ROADMAP.md). The budget row has code to show a warning icon (labelled
"underfunded" for screen readers) when a category's budgeted amount is
below its goal target, but since no category can have a goal, it never
appears.

## Month menu

* **Save as template / Apply template**: stores or applies the positive
  budgets of a month.
* **Copy from previous month**: copies the positive budgets of the previous
  month.
* **Reset budget**: sets all of the month's budgets to 0.

## Updates

All numbers are recomputed when anything relevant is written: the budget
providers watch `ledgerChangesProvider`, which fires after every committed
write to transactions, accounts, budgets, categories, category groups or
payees (local edits, scheduled-transaction catch-up, imports and changes
applied by sync alike). Everything works offline; cloud sync is described in
[SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md).
