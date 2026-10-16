# YNAB Import: Supported Formats

What the YNAB importer reads and how it maps the data. User guide:
[YNAB_MIGRATION.md](YNAB_MIGRATION.md).

Code: `lib/services/import/ynab_import_service.dart` (parsing into
`YnabImportData`, `lib/services/import/models/ynab_import_data.dart`),
`lib/services/import/ynab_data_mapper.dart` (writing to the database),
UI in `lib/presentation/screens/settings/import/ynab/`.

Two sources are supported:

1. **nYNAB CSV export** (current YNAB web app): the `Register` and `Budget`
   CSV files from YNAB's export ZIP, picked separately (any file name).
2. **YNAB 4 budget folder** (`*.ynab4`, legacy desktop app).

The YNAB API is not used.

## 1. nYNAB Register CSV

Header names are matched exactly. Required: `Account`, `Date`, `Payee`,
`Outflow`, `Inflow` (missing ones are listed in the error). Optional:
`Category Group`, `Category`, `Memo`, `Cleared`. Other columns (e.g. `Flag`)
are ignored. Rows shorter than the header are skipped.

- **Date**: one format for the whole file, detected once: the first of
  `MM/dd/yyyy`, `dd/MM/yyyy`, `yyyy-MM-dd`, `dd.MM.yyyy` that parses
  *every* row strictly (no roll-over: `13/05/2025` never becomes a date in
  2026). A file whose days never exceed 12 is read as `MM/dd/yyyy` (YNAB's
  US default). If no format fits every row, the import stops with a
  localised error naming the first value the best-fitting format rejects
  (`YnabImportFailure.invalidDates`). Stored as UTC midnight of the
  calendar day.
- **Amount**: `Inflow - Outflow`, each cell parsed by `MoneyParser`
  (currency symbols and either decimal style accepted; empty = 0), stored in
  minor units.
- **Cleared**: values starting with `R` are reconciled, `C` cleared,
  anything else uncleared.
- **Accounts**: one per distinct `Account` name. The type is guessed from the
  name (`checking`, `saving`, `credit`/`card`, `cash`; default checking).
  The CSV has no closed flag; all accounts are imported as open.
- **Categories**: every distinct `Category Group` / `Category` pair.
- **Splits**: nYNAB writes one row per split line with the memo prefixed
  `Split (i/n)`. Consecutive rows of the same account and date with the same
  `n` and distinct `i` are grouped into one split transaction (marker removed
  from the memo, amount = sum of the lines). A lone split row is imported as
  a normal row.
- **Transfers**: a payee `Transfer : <Account Name>` marks a transfer.

## 2. nYNAB Budget CSV

Optional for parsing but required by the UI. Uses `Month`, `Category Group`,
`Category`, `Budgeted` (all four must exist, otherwise the file is ignored).
`Activity` and `Available` are ignored; LedgerZero recalculates them from
the transactions.

- **Month**: `MMM yyyy` / `MMMM yyyy` with English month names (e.g.
  `Jan 2024`; parsed with the `en_US` locale whatever the app language),
  or one of the register date formats. Rows with an unreadable month are
  skipped (logged).
- Rows with `Budgeted` = 0 are skipped.

## 3. YNAB 4 folder

The folder must contain `Budget.ymeta` and a `data*` subfolder with a device
folder holding `Budget.yfull` (JSON). Tombstoned entities are skipped.

Read from `Budget.yfull`: `accounts` (name, type, `hidden` = closed,
`onBudget`), `payees`, `masterCategories` (groups, `isHidden`),
`subCategories` (`isHidden`), `transactions`,
`subTransactions` (split lines), `scheduledTransactions`, `monthlyBudgets`.
Amounts are major-unit numbers, converted to minor units.

- Account types: `Checking`, `Savings`, `CreditCard`/`LineOfCredit` (credit),
  `Cash`/`MerchantAccount`/`PayPal` (cash); everything else checking.
- Transfers use `targetAccountId`.
- Scheduled frequencies map to LedgerZero recurrence (`Never` = one
  occurrence, `EveryOtherWeek` = every 2 weeks, `TwiceAMonth` = every 2 weeks
  as the closest match, `EveryOtherMonth`, `TwiceAYear`, `Yearly`,
  `EveryOtherYear`, `Daily`, `Weekly`, `Monthly`).
- `onBudget: false` marks a tracking account (see section 4).
- A subcategory whose master category is not listed (YNAB 4 keeps hidden
  categories under a hidden "Hidden Categories" master) gets a hidden group
  of that name.

## 4. Writing the data

The whole import runs in one unit of work: all or nothing.

- **Categories**: groups and categories are matched by name (group +
  category) and created if missing. YNAB's `Internal Master Category`,
  `Inflow` group, `Uncategorized` and the "Ready to Assign" / "To be
  Budgeted" inflow category are not created; transactions in them get no
  category and count towards To Be Budgeted. Hidden YNAB 4 groups and
  categories are created too; their categories are hidden (LedgerZero
  groups have no hidden flag), and their transactions keep the category.
- **Accounts**: matched by name or created with starting balance 0 and the
  currency chosen on the import preview (default: the app's default
  currency from Settings). Closed accounts are imported as closed, with
  their transactions. Tracking accounts (`onBudget: false`) are not
  imported, nor are their own transactions; the result screen reports how
  many were skipped (`YnabImportSummary.trackingAccountsSkipped`). YNAB's "Starting Balance" row is imported as an
  uncategorised transaction.
- **Payees**: matched by name (case-insensitive) or created. Transfer payees
  never become payees.
- **Transfers**: rows that pair up (same day, opposite amounts, accounts
  pointing at each other, no category, not split) become two linked legs.
  Unpaired transfer rows are imported as normal rows with `Transfer : X` in
  the memo. This includes the budget-side leg of a transfer to or from a
  tracking account: it becomes an outflow/inflow of the budget account,
  keeping YNAB's category when it has one (YNAB requires one for outflows
  to tracking accounts), otherwise uncategorised and counted towards To Be
  Budgeted. The budget invariant (available + To Be Budgeted = account
  balances) holds because only budget accounts exist.
- **Splits**: a parent (account-side amount, no category) plus one child per
  line; any difference to the parent goes into an uncategorised child. A split line
  that is a transfer becomes an uncategorised child with `Transfer : X` in
  the memo (the link to the other account is lost; balances stay correct).
- **Scheduled transactions** (YNAB 4 only): scheduled transfers become
  normal scheduled transactions of the source account with `Transfer : X` in
  the memo.
- **Budgets**: one row per category and month with a deterministic id;
  existing rows for the same category and month are overwritten.
- **Not imported**: goals, flags, account notes, tracking accounts.
