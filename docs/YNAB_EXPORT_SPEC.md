# YNAB Import: Supported Formats

What the YNAB importer reads and how it maps the data. User guide:
[YNAB_MIGRATION.md](YNAB_MIGRATION.md).

Code: `lib/services/import/ynab_import_service.dart` (parsing into
`YnabImportData`, `lib/services/import/models/ynab_import_data.dart`),
`lib/services/import/ynab_data_mapper.dart` (writing to the database),
UI in `lib/presentation/screens/settings/import/ynab/`.

Two sources are supported:

1. **nYNAB CSV export** (current YNAB web app): the `Register` and the
   `Budget` (in newer exports `Plan`) CSV files of YNAB's export, taken
   out of the export ZIP (`YnabImportService.readExportZip`) or picked
   separately (any file name).
2. **YNAB 4 budget folder** (`*.ynab4`, legacy desktop app), as a ZIP of
   the folder (`parseYnab4Zip`) or as the folder itself (`parseYnab4`).

In the export ZIP the two files are told apart by their header line (the
register has `Outflow` and `Inflow`, the budget file `Month` and
`Budgeted` or `Assigned`); a CSV whose header says nothing is taken by its
name (`Register`, `Budget`, `Plan`). The exact header row of YNAB's
current "Plan" export was not available when this was written: `Assigned`
is accepted next to `Budgeted` on that assumption, and a budget file with
neither stops the import with an error rather than being skipped.

The YNAB API is not used.

## 1. nYNAB Register CSV

Header names are matched ignoring case and surrounding spaces. The file is
comma-separated, or tab-separated (YNAB's export for budgets whose number
format has a decimal comma); the delimiter is read from the header line.
Required: `Account`, `Date`, `Payee`, `Outflow`, `Inflow` (missing ones are
listed in the error). Optional: `Category Group`, `Category`, `Memo`,
`Cleared`. Other columns (e.g. `Flag`) are ignored. Rows shorter than the
header are skipped.

- **Date**: one format for the whole file, detected once: the first of
  `MM/dd/yyyy`, `dd/MM/yyyy`, `yyyy-MM-dd`, `dd.MM.yyyy`, `yyyy/MM/dd`,
  `dd-MM-yyyy`, `yyyy.MM.dd` (YNAB's date settings) that parses
  *every* row strictly (no roll-over: `13/05/2025` never becomes a date in
  2026). A file whose days never exceed 12 is read as `MM/dd/yyyy` (YNAB's
  US default); every format that fits is listed in
  `YnabImportData.dateFormatCandidates` and the preview lets the user
  switch (`parseCsvExport(dateFormat:)` re-reads the file with the chosen
  one; `registerDateFormat` names the one in use). If no format fits every
  row, the import stops with a localised error naming the first value the
  best-fitting format rejects (`YnabImportFailure.invalidDates`). Stored
  as UTC midnight of the calendar day.
- **Amount**: `Inflow - Outflow`, each cell parsed by `MoneyParser`
  (currency symbols and either decimal style accepted; empty = 0), stored in
  minor units. The decimal separator is inferred once from all amount
  cells of both files (`inferDecimalSeparator`), so an export without
  decimals (`€1.234`) is read as thousands. YNAB writes the budget's
  currency symbol into every cell; when `MoneyParser` does not know it
  (`R1 234.56`, `1 234,56 Kč`, `Rp 1.234`, `RM`, `lei`, `฿`), whatever
  stands before the first and after the last digit is dropped (a minus
  sign or an opening parenthesis there still negates). A non-empty cell
  that is not a number even then stops the import
  (`YnabImportFailure.invalidAmount`, the cell in the error); it is never
  read as 0.
- **Cleared**: values starting with `R` are reconciled, `C` cleared,
  anything else uncleared.
- **Accounts**: one per distinct `Account` name. The type is guessed from the
  name (`checking`, `saving`, `credit`/`card`, `cash`; default checking).
  The CSV has no closed flag; all accounts are imported as open. It has no
  tracking flag either, so `onBudget` is inferred from the trace YNAB
  leaves: a transfer between two budget accounts has no category on
  either leg, a transfer between a budget account and a tracking account
  always has one on the budget-side leg (the spending category,
  `Uncategorized`, or `Inflow: Ready to Assign` for money coming back).
  An account with rows of its own (anything but `Starting Balance` and
  transfer legs) is a budget account. An account without such rows gets
  `onBudget: false` when a leg facing it in a budget account carries a
  category, stays on budget when it has such legs and none carries one
  (a savings account that is only topped up), and gets `onBudget: false`
  when there is no such leg at all (a house, a loan). The preview switch
  overrides it per account.
- **Categories**: every distinct `Category Group` / `Category` pair of the
  register, plus every pair of Budget.csv that the register lacks
  (`YnabImportData.categoriesOnlyInBudget` counts those).
- **Fingerprint**: SHA-256 of the register text
  (`YnabImportData.fingerprint`), kept in SharedPreferences by
  `YnabImportHistory` after a successful import so the preview can warn
  about a second import of the same export.
- **Splits**: nYNAB writes one row per split line with the memo prefixed
  `Split (i/n)`. Consecutive rows of the same account and date with the same
  `n` and distinct `i` are grouped into one split transaction (marker removed
  from the memo, amount = sum of the lines). A lone split row is imported as
  a normal row.
- **Transfers**: a payee `Transfer : <Account Name>` marks a transfer.

## 2. nYNAB Budget CSV

Optional for parsing (an empty file is no error) but required by the UI.
Called `Budget.csv`, in newer exports `Plan.csv`. Uses `Month`, `Category
Group`, `Category` and the amount column, which is `Budgeted` or
`Assigned`; a file with only the combined `Category Group/Category` column
is split at the first colon. A non-empty file that lacks one of them stops
the import with `YnabImportFailure.missingBudgetColumns` (the missing
names in the error) instead of being skipped: a skipped budget file left
every category at 0 budgeted and all past spending overspent. Comma- or
tab-separated and header names matched like the register's. `Activity`
and `Available` are ignored; LedgerZero recalculates them from the
transactions.

- **Month**: `MMM yyyy` / `MMMM yyyy` with English month names (e.g.
  `Jan 2024`; parsed with the `en_US` locale whatever the app language),
  or one of the register date formats. Rows with an unreadable month are
  skipped (logged).
- Rows with `Budgeted` = 0 are skipped.

## 3. YNAB 4 folder

The folder must contain `Budget.ymeta` and a `data*` subfolder with a device
folder holding `Budget.yfull` (JSON). Tombstoned entities are skipped.

**ZIP.** `parseYnab4` reads the folder by path. Android 11 and later do
not let an app read another app's non-media files by path, so a folder
picked with the system picker is usually unreadable there (not verified
on a device). `parseYnab4Zip` reads a ZIP of the folder instead, picked as
a single file, which works on every Android version. The ZIP may hold the
`.ynab4` folder or its content at the top; the bundle's root is where the
shallowest `Budget.ymeta` lies, and `__MACOSX` entries are ignored.

**Which `Budget.yfull`.** A budget used on several computers has one
folder per device, each with its own full budget file, and some are stale.
`Budget.ymeta` names the current data folder (`relativeDataFolderName`).
In it, every `devices/*.ydevice` describes a device: `deviceGUID` (its
folder), `hasFullKnowledge` and `knowledgeInFullBudgetFile` (a version per
device, e.g. `A-120,B-45`). The file of the device with full knowledge and
the highest versions is imported (`knowledge` breaks ties). A bundle
without readable metadata falls back to the first `Budget.yfull` by path,
so the choice is the same every time. Changes that exist only as `.ydiff`
files newer than the chosen full budget file are not applied.

Read from `Budget.yfull`: `accounts` (name, type, `hidden` = closed,
`onBudget`), `payees`, `masterCategories` (groups, `isHidden`) with their
nested `subCategories` (`isHidden`), `transactions` with their nested
`subTransactions` (split lines), `scheduledTransactions`, `monthlyBudgets`
(with nested `monthlySubCategoryBudgets`). Flattened files that list
`subCategories` or `subTransactions` at the top level are read as well.
Amounts are major-unit numbers, converted to minor units. The internal
master category `MasterCategory/__Internal__` is not a group: its
`Category/__ImmediateIncome__` and `Category/__DeferredIncome__` are
income (rows in them get no category and count towards To Be Budgeted)
and `Category/__Split__` marks split parents. The fingerprint is the
SHA-256 of `Budget.yfull`.

- Account types: `Checking`, `Savings`, `CreditCard`/`LineOfCredit` (credit),
  `Cash`/`MerchantAccount`/`PayPal` (cash); everything else checking.
- Transfers use `targetAccountId`.
- Scheduled frequencies map to LedgerZero recurrence (`Never` = one
  occurrence, `EveryOtherWeek` = every 2 weeks, `TwiceAMonth` = every 2 weeks
  as the closest match, `EveryOtherMonth`, `TwiceAYear`, `Yearly`,
  `EveryOtherYear`, `Daily`, `Weekly`, `Monthly`).
- `onBudget: false` marks a tracking account (see section 4); the preview
  switch can change it.
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
  their transactions. Tracking accounts (`onBudget: false`) are created
  with "Include in budget" off and imported with their transactions, which
  get no category (the budget ignores categories on off-budget rows); the
  result screen reports how many (`YnabImportSummary.trackingAccounts`).
  YNAB's "Starting Balance" row is imported as an uncategorised
  transaction.
- **Payees**: matched by name (case-insensitive) or created. Transfer payees
  never become payees.
- **Transfers**: rows that pair up (same day, opposite amounts, accounts
  pointing at each other, at most one of them categorised, not split)
  become two linked legs. A transfer between a budget account and a
  tracking account keeps YNAB's category on the budget-side leg (YNAB
  requires one for outflows to tracking accounts): the app's cross-budget
  rule, the money leaves that category; without a category the leg counts
  towards To Be Budgeted. Between two budget accounts a category is
  dropped (the budget ignores it). Unpaired transfer rows are imported as
  normal rows with `Transfer : X` in the memo. The budget invariant
  (available + To Be Budgeted = on-budget account balances) holds.
- **Splits**: a parent (account-side amount, no category) plus one child per
  line; any difference to the parent goes into an uncategorised child. A split line
  that is a transfer becomes an uncategorised child with `Transfer : X` in
  the memo (the link to the other account is lost; balances stay correct).
- **Scheduled transactions** (YNAB 4 only): scheduled transfers become
  normal scheduled transactions of the source account with `Transfer : X` in
  the memo.
- **Budgets**: one row per category and month with a deterministic id;
  existing rows for the same category and month are overwritten.
- **Not imported**: goals, flags, account notes.
