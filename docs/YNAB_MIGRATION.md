# YNAB Migration Guide

LedgerZero imports a budget from the current YNAB web app (CSV export) or
from YNAB 4 (classic desktop app). Format details:
[YNAB_EXPORT_SPEC.md](YNAB_EXPORT_SPEC.md).

## Prepare the files

- **nYNAB (web app)**: use YNAB's budget export. It downloads a ZIP with two
  CSV files, `... - Register.csv` (transactions) and `... - Budget.csv`
  (monthly budgeted amounts). Unzip it and put both files where the phone's
  file picker can reach them (e.g. Google Drive or Downloads). Do not open
  and re-save them in a spreadsheet app.
- **YNAB 4**: copy the budget folder (name ending in `.ynab4`) to a location
  the phone can open as a folder.

## Steps

1. Open **Settings** (gear icon on Home) > **Manage data** > **YNAB
   Migration**.
2. Under **Select your YNAB version** choose **nYNAB (CSV Export)** or
   **YNAB 4 (Classic)**.
3. Pick the files:
   - nYNAB: select the Register file and the Budget file (both are
     required).
   - YNAB 4: select the budget folder.
4. Tap **Next: Preview**. The **Import Preview** shows the accounts (with
   type and open/closed, and a **Tracking account** switch), the categories
   per group, and the number of transactions, categories, budget entries
   and (YNAB 4 only) scheduled transactions. For an nYNAB export whose
   dates fit both day/month orders, a **Date format in Register.csv**
   dropdown lets you switch between them. If the same export was imported
   before, the preview says so with the date.
5. Tap **Confirm & Import** and keep the app open until it finishes.
6. On the success screen tap **Start Budgeting** to open the Budget tab.

If the import fails, nothing is written ("The import failed. No data was
changed; please try again.").

## What is imported

| Data | nYNAB CSV | YNAB 4 |
|---|---|---|
| Accounts | yes (type guessed from the name, all open; tracking accounts inferred, see below) | yes (type, closed state and tracking flag) |
| Category groups and categories | yes, including categories that only appear in Budget.csv | yes, hidden ones as hidden categories |
| Transactions, cleared/reconciled state | yes | yes |
| Split transactions | yes | yes |
| Transfers between accounts | yes, as linked transfers when both legs are found | yes |
| Payees | yes | yes |
| Monthly budgeted amounts | yes | yes |
| Scheduled transactions | no (not in the export) | yes |
| Goals, flags | no | no |

## After the import

- **Currency**: YNAB exports contain no currency. The import preview has a
  **Currency of the imported accounts** field, preset to your default
  currency from Settings; all accounts the import creates get that
  currency. Change it per account afterwards if your accounts use different
  currencies.
- **Account types**: for nYNAB the type is guessed from the account name;
  check it on each account.
- **Credit card payment categories**: LedgerZero has none. Payments to a
  credit card are plain transfers.
- **Ready to Assign**: income assigned to YNAB's "Ready to Assign" / "To be
  Budgeted" is imported without a category and counts towards To Be
  Budgeted.
- **Tracking (off-budget) accounts**: imported as accounts with "Include
  in budget" off (see docs/BUDGETING_RULES.md), with their transactions
  (uncategorised: the budget ignores categories on off-budget rows). YNAB 4
  states which accounts are tracking accounts; nYNAB CSV exports do not, so
  an account whose rows are only its "Starting Balance" and transfers is
  preset as a tracking account and the preview's **Tracking account**
  switch lets you change it per account. A transfer between a budget
  account and a tracking account is how money leaves or enters the budget:
  the two legs are linked like any transfer, and the category YNAB put on
  the budget-side leg (YNAB requires one for such outflows) stays there, so
  the money leaves that category instead of To Be Budgeted, exactly as the
  app's own transfer form does. Without a category the budget-side leg
  counts towards To Be Budgeted. The result screen says how many tracking
  accounts were created.
- **Categories only in Budget.csv**: a category you budgeted but never
  used in a transaction (a sinking fund, a credit card payment category)
  has no register row. It is created too, so its budgeted amounts are not
  lost; the preview counts them under "Categories only in Budget.csv".
- **Amount format**: both `$1,234.56` and `1.234,56 €` are read; the
  decimal separator is inferred from the whole export, so `€1.234` (no
  decimals) is one thousand two hundred thirty-four, not 1.23.
- **Hidden categories** (YNAB 4): imported as hidden categories, so their
  transactions keep their category. LedgerZero cannot hide a whole group;
  every category of a hidden YNAB group is hidden instead.

## FAQ

**Will importing twice duplicate data?**
Accounts, categories and payees are matched by name and reused. Budgeted
amounts are overwritten per category and month. Transactions are always
added, so a second import of the same file duplicates them. The app
remembers imported exports by their content (on this phone) and the
preview warns "This export was already imported on …"; the warning does
not stop the import. There is no undo; create a backup (**Settings >
Backup & Export**) before importing into a budget that already has data.

**How are splits handled?**
As a split transaction: a parent with one line per category. In the nYNAB
CSV, split lines are recognised by YNAB's `Split (i/n)` memo prefix.

**Why are some transactions uncategorised?**
They were in YNAB's inflow category (nYNAB "Ready to Assign", YNAB 4's
income categories), belong to a tracking account, were an uncategorised
transfer to or from a tracking account, or were a transfer line inside a
split.

**My dates came out swapped (5 March became 3 May).**
The register had no day above 12, so both orders fit. Go back to the
preview and pick the other **Date format in Register.csv**.

## Error messages

| Message | What to do |
|---|---|
| "Please select both Register.csv and Budget.csv." | Pick both files. |
| "Register.csv is missing required columns: ..." | Pick the Register file (not Budget) from an unmodified YNAB export. |
| "The selected files could not be read. Please check that they are unmodified YNAB exports." | Export again from YNAB and do not edit the files. |
| "This folder is not a valid YNAB 4 budget. Please select the folder ending in .ynab4." | Select the `.ynab4` folder itself, not its parent or the `data` folder. |
| "The dates in Register.csv do not fit one date format (...). First unreadable date: ..." | The Date column mixes formats or contains a value that is not a date. Export again from YNAB, or fix the value shown. |
| "This export was already imported on …" (preview warning) | The same file (by content) was imported on this phone before. | Cancel unless you restored a backup from before that import. |
| "The file could not be opened." / "The folder could not be opened." | Pick the file or folder again. |

Register rows are never skipped silently because of their date: one date
format must fit every row, otherwise the import stops with the error above.
See the supported date formats in [YNAB_EXPORT_SPEC.md](YNAB_EXPORT_SPEC.md).
