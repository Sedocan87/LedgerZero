# YNAB Migration Guide

LedgerZero imports a budget from the current YNAB web app (CSV export) or
from YNAB 4 (classic desktop app). Format details:
[YNAB_EXPORT_SPEC.md](YNAB_EXPORT_SPEC.md).

## Prepare the files

- **nYNAB (web app)**: use YNAB's budget export. It downloads a ZIP with two
  CSV files, `... - Register.csv` (transactions) and `... - Budget.csv`
  (monthly budgeted amounts). Unzip it and put both files where the phone's
  file picker can reach them (e.g. Files / iCloud Drive / Google Drive /
  Downloads). Do not open and re-save them in a spreadsheet app.
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
   type and open/closed), the categories per group, and the number of
   transactions, budget entries and (YNAB 4 only) scheduled transactions.
5. Tap **Confirm & Import** and keep the app open until it finishes.
6. On the success screen tap **Start Budgeting** to open the Budget tab.

If the import fails, nothing is written ("The import failed. No data was
changed; please try again.").

## What is imported

| Data | nYNAB CSV | YNAB 4 |
|---|---|---|
| Accounts | yes (type guessed from the name, all open) | yes (type and closed state); tracking accounts are skipped, see below |
| Category groups and categories | yes | yes, hidden ones as hidden categories |
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
- **Tracking (off-budget) accounts** (YNAB 4): not imported yet. You can
  create them in LedgerZero yourself and switch off "Include in budget"
  (see docs/BUDGETING_RULES.md). Tracking accounts and their own
  transactions are skipped; the
  preview marks them "Tracking account – not imported" and the result
  screen says how many were left out. A transfer between a budget account
  and a tracking account is how money leaves or enters the budget, so its
  budget-side leg is imported as a normal outflow or inflow of the budget
  account: with YNAB's category if it had one, otherwise uncategorised (so
  it counts towards To Be Budgeted). Its memo names the transfer
  (`Transfer : House`). nYNAB CSV exports do not say which accounts are
  tracking accounts, so all of their accounts are imported.
- **Hidden categories** (YNAB 4): imported as hidden categories, so their
  transactions keep their category. LedgerZero cannot hide a whole group;
  every category of a hidden YNAB group is hidden instead.

## FAQ

**Will importing twice duplicate data?**
Accounts, categories and payees are matched by name and reused. Budgeted
amounts are overwritten per category and month. Transactions are always
added, so a second import of the same file duplicates them. There is no undo;
create a backup (**Settings > Backup & Export**) before importing into a
budget that already has data.

**How are splits handled?**
As a split transaction: a parent with one line per category. In the nYNAB
CSV, split lines are recognised by YNAB's `Split (i/n)` memo prefix.

**Why are some transactions uncategorised?**
They were in YNAB's inflow category, were an uncategorised transfer to or
from a tracking account, or were a transfer line inside a split.

## Error messages

| Message | What to do |
|---|---|
| "Please select both Register.csv and Budget.csv." | Pick both files. |
| "Register.csv is missing required columns: ..." | Pick the Register file (not Budget) from an unmodified YNAB export. |
| "The selected files could not be read. Please check that they are unmodified YNAB exports." | Export again from YNAB and do not edit the files. |
| "This folder is not a valid YNAB 4 budget. Please select the folder ending in .ynab4." | Select the `.ynab4` folder itself, not its parent or the `data` folder. |
| "The dates in Register.csv do not fit one date format (...). First unreadable date: ..." | The Date column mixes formats or contains a value that is not a date. Export again from YNAB, or fix the value shown. |
| "The file could not be opened." / "The folder could not be opened." | Pick the file or folder again. |

Register rows are never skipped silently because of their date: one date
format must fit every row, otherwise the import stops with the error above.
See the supported date formats in [YNAB_EXPORT_SPEC.md](YNAB_EXPORT_SPEC.md).
