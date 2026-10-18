# Transaction Lifecycle

How a transaction is created, linked, changed and deleted. All writes go
through `TransactionService` (`lib/domain/services/transaction_service.dart`);
screens never write transaction rows through the repository directly. Every
write runs in one unit of work and records one undo action.

## Fields that matter here

| Field | Meaning |
| --- | --- |
| `amount` | `int` minor units, signed (negative = outflow). Zero is rejected. |
| `date` | Calendar day, stored as UTC midnight (`CalendarDate`). |
| `cleared` | `TransactionClearStatus`: `uncleared`, `cleared`, `reconciled` (stored as its index 0/1/2). |
| `approved` | `bool`, default `true`. |
| `isDeleted` | Soft-delete flag. |
| `transferAccountId`, `transferTransactionId` | Set on both legs of a transfer. |
| `parentTransactionId` | Set on split lines (children). |

## Creation

`TransactionService.save(TransactionInput)` creates or updates a normal,
transfer or split transaction. Validation (`ValidationException` with a
`TransactionValidationError` code):

* the amount is not zero;
* a transfer has a different target account and is not split;
* split lines are non-zero and add up exactly to the parent amount.

Defaults for a new row: `uncleared`, `approved: true`, not deleted. A new
payee name is resolved case-insensitively to an existing payee or created.
When a *new* transaction is saved with a payee and a category, the payee's
default category (`autoCategoryId`) is updated to that category; editing a
transaction never relearns (a one-off correction must not replace the
default). The form starts a new transaction with the Settings default
account (if it is open and not the partner's) and default category; a
payee's own default category and rule suggestions replace the latter.

Further rules of `save`:

* The row's account must be on budget for a category to be stored; rows
  of off-budget accounts are saved without one (quick-add and card capture
  may pass a category). The cross-budget transfer rule below is the
  exception.
* `approved` is part of the input: the form loads the stored value and
  shows an "Approved" switch when editing, so an edit never approves a
  captured card payment or scheduled occurrence silently.
* Only rows whose content changed are written and recorded for undo
  (timestamps aside). Editing the memo of a split leaves its children's
  `updated_at` alone, and changing one transfer leg's cleared flag leaves
  the other leg alone, so last-writer-wins sync never discards the
  partner's concurrent edit of an untouched row. A reconciled row the edit
  does not touch needs no confirmation.

Where rows come from besides the form:

* Quick add (see [NATURAL_LANGUAGE_FORMATS.md](NATURAL_LANGUAGE_FORMATS.md)).
* Scheduled occurrences: `approved` = the schedule's `autoApprove`
  (default off), see [SCHEDULED_TRANSACTIONS.md](SCHEDULED_TRANSACTIONS.md).
* CSV and YNAB import: created `approved`.
* Rules (`RuleMatchingService`) can set `approved` and `cleared` when they
  run automatically; see [RULES.md](RULES.md).

`approved` does not change balances or budget numbers; unapproved rows
count like any other and are marked in the transaction list. The list's
selection mode can approve several rows at once.

## Clearing and reconciliation

* `updateClearingStatus` sets one row's status; a split changes as a
  whole, also when a line is given (e.g. from a category's activity list):
  the parent and all its lines get the status. Approve / reject work the
  same way.
* The reconciliation screen (`/accounts/:id/reconcile`) calls
  `TransactionService.reconcile`: every `cleared` row of the account dated on
  or before the statement date becomes `reconciled`; if the cleared balance
  differs from the statement balance, an uncategorised, reconciled
  adjustment is added on the statement date (it flows into To Be Budgeted).
* Changing or deleting a reconciled row (or a row linked to one) throws
  `ReconciledTransactionException` unless the caller passes
  `allowReconciledChange: true`; the UI asks the user first. Approve,
  reject, bulk categorise and mark-as-reconciled are allowed on reconciled
  rows without asking.

## Transfers

Two rows linked both ways:

* each leg has `transferTransactionId` = the other leg's id and
  `transferAccountId` = the other leg's account;
* the counterpart is always derived from the edited leg (`-amount`, same
  date and memo), so editing either leg keeps its direction;
* transfer legs carry no payee. Within the budget (both accounts on
  budget, or both off budget) they carry no category and do not touch To
  Be Budgeted. A transfer that crosses the budget boundary (exactly one
  account on budget) may carry a category on its on-budget leg: the money
  then moves out of (or into) that category instead of To Be Budgeted; an
  uncategorised cross-budget leg flows into To Be Budgeted like any other
  uncategorised row (see [BUDGETING_RULES.md](BUDGETING_RULES.md));
* both accounts must use the same currency
  (`TransactionValidationError.currencyMismatch`; the account picker only
  offers same-currency targets). The app has no exchange rates, and net
  worth is shown per currency when accounts differ;
* converting a normal transaction to a transfer creates the counterpart;
  converting back deletes it;
* each leg has its own cleared status: the form shows a switch per leg
  (`TransactionInput.counterpartCleared`); when it is omitted the
  counterpart keeps its own status unless it moves to another account
  (then it starts `uncleared`).

## Splits

A parent row plus child rows:

* the parent carries the account-side amount and no category; it counts
  for the account balance only;
* children have `parentTransactionId`, the parent's account, date, payee,
  cleared and approved state, and their own category, amount and memo;
  they count as category activity (uncategorised lines count towards To Be
  Budgeted);
* on edit, children are matched by id, so their ids survive; removed lines
  are soft-deleted;
* the main transaction list hides split children unless it is filtered by
  category (e.g. "Activity" from the budget screen); a search still finds
  the split through its lines (memo, category, amount) and lists the
  parent;
* bulk categorise skips split parents and transfer legs, except the
  on-budget leg of a cross-budget transfer.

## Deletion

Deletion is soft (`isDeleted = true`). Soft-deleted rows are excluded from
balances, budget numbers, reports and lists, and are kept so the deletion
syncs to other devices and can be undone.

Deleting any row of a group deletes the whole group: both transfer legs, or
a split parent with all its children (also when deleting a single split
line). `previewDeletion` tells the UI what will be deleted.

Hard deletes happen only when a whole account is deleted (see
[BUDGETING_RULES.md](BUDGETING_RULES.md#deleting-things)).

## Undo and redo

* `UndoService` (`lib/domain/services/undo_service.dart`) keeps in-memory
  undo and redo stacks of `ReversibleAction`s, at most 50 each. They are
  lost when the app restarts or the database is reopened.
* Transaction writes record a `TransactionChangeSetAction`
  (`lib/domain/undo/transaction_undo_actions.dart`): a snapshot of every
  touched row before and after. Undo writes the "before" states back in one
  unit of work (restoring whole transfer and split groups); undoing a create
  soft-deletes the rows.
* Budget edits on the budget screen record a `BudgetChangeAction`.
* Snackbars pass the action they announced to `undo`, so a later action is
  never undone by mistake.
* Deleting a category, payee or account clears both stacks
  (`UndoService.clear()`, called by `CategoryService`, `PayeeService` and
  `AccountService`): a recorded snapshot may reference the deleted entity
  and restoring it would fail on a foreign key. Restoring a backup reopens
  the database and clears them as well.
