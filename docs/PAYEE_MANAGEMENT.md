# Payee Management

Payees are managed under Settings > Payees (`/settings/payees`,
`PayeesScreen`); tapping a payee opens `PayeeDetailScreen`
(`/settings/payees/:id`). Deletes and merges run through `PayeeService`
(`lib/domain/services/payee_service.dart`).

## Creating payees

Payees are created implicitly: when a transaction is saved with a payee name
that does not exist yet (compared case-insensitively), `TransactionService`
creates it. CSV and YNAB imports create payees the same way.

In the transaction form the payee field suggests existing payees whose
name contains the typed text. Tapping a suggestion picks that payee. The
keyboard's "Next" keeps the typed text as it is, unless it is exactly an
existing payee's name (ignoring case), which picks that payee; it never
takes the first suggestion, so "Corner" can be entered next to an
existing "Corner Shop".

## Payee list

* Search by name (case-insensitive substring).
* Sorted favourites first, then by name.
* Export as CSV from the app bar. Columns (English, a machine format):
  Name, Is Favorite, Notes, Auto Category ID, Default Account ID,
  Created At.

## Payee detail

* Rename, favourite (star), icon, colour, notes.
* **Rename** (`PayeeService.renamePayee`): a name that another payee
  already has (ignoring case) is refused, because two payees with one name
  cannot be told apart when the name is typed, imported or matched by a
  rule; the dialog offers to merge into that payee instead. Rule conditions
  "Payee is <old name>" are changed to the new name in the same unit of
  work, unless another payee still has the old name (a duplicate from
  before names were checked). Conditions with "contains", "starts with",
  "ends with" or a pattern are left as typed.
* **Auto category**: the category pre-filled when this payee is picked in
  a new outflow (an inflow stays in To Be Budgeted unless a category is
  picked for it). It is also learned: saving a new transaction with this
  payee and a category sets the payee's auto category to that category.
* **Default account**: pre-filled when the payee is picked in a new
  transaction and no account is chosen yet, unless it was closed since.
* Usage statistics (times used, total spent, last used) and the payee's
  transactions.

## Payee suggestions in the transaction form

The payee field suggests existing payees ordered by: favourites first, then
number of (non-deleted) transactions, then most recent use, then name.

## Merging

Menu > Merge on the payee to remove (the source), then pick the target.
`PayeeService.mergePayees` runs in one unit of work:

1. every reference to the source is pointed at the target: all
   transactions (including soft-deleted ones), scheduled transactions,
   quick-add parsing rules and parsing history;
2. rule actions that set the source payee are changed to the target;
3. the source payee is deleted;
4. rule conditions "Payee is <source name>" are changed to the target's
   name (unless another payee still has the source's name), so a rule such
   as the suggested "Rewe -> Groceries" keeps matching.

Merging is not on the undo stack; the confirmation dialog says so.

## Deleting

Menu > Delete. `PayeeService.deletePayee` clears the payee from every
transaction (they keep their amounts and categories), scheduled transaction,
parsing rule and parsing history entry, removes rule actions that set it (a
rule left without actions is deactivated, not deleted), then deletes the
payee. Balances and budget numbers do not change.
