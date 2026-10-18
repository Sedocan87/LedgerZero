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
  `budgetViewModelProvider`. Hidden categories are not listed; a hidden
  category that still has money budgeted or available (or activity) in the
  month appears in a last, collapsed **Hidden categories** section, because
  that money still counts in To Be Budgeted and must stay reachable (edit
  the amount or move the money out). The footer totals include that
  section.
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
   month's budget row (created with its deterministic id if missing). A
   negative result is rejected with a message (it would raise To Be
   Budgeted).
3. A `BudgetChangeAction` is pushed on the undo stack and a snackbar offers
   Undo. If the undo fails (the category was deleted meanwhile), the
   generic error snackbar is shown.

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
amount; source and target must differ. Hidden categories are not offered,
except the one the modal was opened from (so money can be moved out of a
hidden category from the Hidden categories section). `BudgetingService.moveMoney`
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

All three operations skip hidden categories (like the new-month fill),
touch only the categories whose amount changes, record one
`BudgetMonthChangeAction` on the undo stack and show a snack bar with Undo
(undo restores the previous amounts of the changed categories in one unit
of work; a category deleted in the meantime is skipped). Copy and apply
ask before overwriting a month that already has budgets ("Replace budgeted
amounts?"); reset always asks.

* **Save as template**: stores the positive budgets of the month's visible
  categories.
* **Apply template**: a *merge*: only the categories in the template are
  set to the template's amounts, every other category keeps its amount
  (the dialog says so). Entries whose category was deleted or hidden are
  skipped.
* **Copy from previous month**: sets every category budgeted in the month
  before to that amount; other categories keep theirs.
* **Reset budget**: sets every visible category of the month to 0.
* **Fill automatically…**: the setting described below.

## Filling a new month

Code: `BudgetingService.fillEmptyCategories` / `planFill` / `undoFill`,
`NewMonthFillController` (`lib/presentation/providers/new_month_fill_provider.dart`),
`NewMonthCard` and `AutoFillNoteCard`
(`lib/presentation/screens/budget/widgets/new_month_card.dart`).

* **Leftover card** (`LeftoverCard`, `leftoverProvider`): in the current
  month, when the month before was budgeted and left money unassigned that
  is still in To Be Budgeted: *Budget for savings…* (category picker with
  the Savings & Investments group first; snack bar with Undo) or *Keep for
  (month)*, which hides it for the month. Not shown for a new budget: a
  starting balance counts in every month and is no leftover.
* **New-month card**: for the current or a later month with nothing budgeted
  whose previous month has budgets. It shows the total, To Be Budgeted after
  filling and the income still expected, and offers *Fill like (previous
  month)*, *Use a template* (when templates exist) and *Not now* (hides it
  for that month). Filling shows a snack bar with Undo.
* **Fill new months automatically** (off by default; the month before or a
  template): runs at start-up and on resume, once per month and phone, and
  only when the month is still empty. It starts with the month after it
  was turned on. A card ("November was filled automatically") offers Undo.
  If the template was deleted, the month before is used and the setting
  switches to it.
* Both only fill categories that are still at zero (never hidden ones) and
  never overwrite an amount. Undo resets only the categories still at the
  filled amount.
* **Sync**: the automatic fill stores the first day of the month, 00:00 UTC
  (`BudgetingService.automaticFillStamp`), as the rows' `updated_at`, and
  skips categories written at or after that time. Any edit by hand, on
  either phone, is therefore newer and wins; two phones filling the same
  month agree; and an automatic amount that loses is not recorded as a
  conflict (see SYNC_ARCHITECTURE.md, section 5). The one-tap card writes
  ordinary edits.

## Updates

All numbers are recomputed when anything relevant is written: the budget
providers watch `ledgerChangesProvider`, which fires after every committed
write to transactions, accounts, budgets, categories, category groups or
payees (local edits, scheduled-transaction catch-up, imports and changes
applied by sync alike). Everything works offline; cloud sync is described in
[SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md).

## In-app help

ⓘ buttons (`InfoButton`, `lib/presentation/widgets/help/`) open a bottom
sheet: a short text, steps, and "Open the user guide" at the matching
chapter (`/settings/help/user-guide?chapter=<GuideChapter>`). Topics
(`HelpTopic`) and their places: Savings & Investments group header (saving),
To Be Budgeted banner, new-month card, account form (type, Include in
budget, Personal), Accounts app bar (net worth and badges), transfer
category hint, Sync settings, CSV import and the app lock switch. The sheet
and the guide share their wording through `app_*.arb` (`help*`, `guide*`).

One-time hints (remembered in SharedPreferences once dismissed or shown):

| Hint | Where | Key |
|---|---|---|
| Move budgeted savings with a transfer | Savings & Investments group, once money is budgeted there | `hint_savings_transfer_seen` |
| How to save into an account outside the budget | Snack bar after creating the first off-budget account | `hint_offbudget_account_seen` |
| What the partner's accounts are | Accounts list, above the partner's accounts | `hint_partner_accounts_seen` |
