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
When a payee and a category are saved together, the payee's default
category (`autoCategoryId`) is updated to that category.

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

* `updateClearingStatus` sets one row's status; split lines follow their
  parent.
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
* transfer legs carry no category and no payee and never count towards To
  Be Budgeted;
* converting a normal transaction to a transfer creates the counterpart;
  converting back deletes it;
* the counterpart keeps its own cleared status unless it moves to another
  account (then it starts `uncleared`).

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
  category (e.g. "Activity" from the budget screen).

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
