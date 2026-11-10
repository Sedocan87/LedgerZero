# CSV Import Troubleshooting

Problems with **Settings > Manage data > Import CSV**. The file format is
described in [CSV_FORMAT.md](CSV_FORMAT.md).

## Messages when opening the file

| Message | Cause | What to do |
|---|---|---|
| "The file could not be opened." | The file could not be read from the picker. | Download the export again and pick the local copy. |
| "The CSV file contains no data." | The file is empty. | Check the export in a text editor. |
| "This file could not be read as CSV. Please check its format." | The file is not parseable CSV. | Make sure it is a CSV/TXT export with comma or semicolon separators, not an Excel or PDF file. |

## Validation messages

Shown when you continue from the mapping screen.

| Message | Cause | What to do |
|---|---|---|
| "Choose the column that contains the date." / "...the amount." | Date or Amount is set to *Ignore*. | Map both on the Column Mapping card. |
| "The selected columns are not in this file." | A loaded profile refers to headers this file does not have. | Map the columns again (header names must match exactly, including case). |
| "The file has no data rows below the column headers." | Only a header was found. | Check that the export contains transactions and that the right line was taken as the header. |
| "N rows have dates that do not match the format ... and will be skipped." (warning) | A few rows (footer lines such as `Kontostand`, or a typo) have no readable date. | You can continue; those rows are left out. |
| "N rows have dates that do not match the format ..." (error) | More than 20 % of the rows (and more than 3) do not fit the **Date Format**. | Pick the format that matches the file (e.g. `dd.MM.yyyy` or `dd.MM.yy` for German banks), or the right **Bank format**. |
| "N rows have unreadable amounts and will be skipped." (warning) | A few amount cells are empty or not a number. | You can continue; those rows are left out. |
| "N rows have unreadable amounts. Check the Amount column and the decimal separator." (error) | Most amount cells cannot be read: wrong column (e.g. `Lastschrift Ursprungsbetrag` instead of `Betrag`) or wrong **Decimal Separator**. | Map Amount to the signed amount column (or Debit and Credit under **More columns**) and set the separator. |
| "Day and month could be swapped: both ... fit every date." (warning) | No day above 12 in the file, so `dd/MM` and `MM/dd` both fit; the app language chose. | Check a date on the review screen and switch the **Date Format** if needed. |
| "N dates are far from the others..." (warning) | A date more than a year from the median, usually a typo in the file. | Check the dates on the review screen. |
| "All N amounts would be imported as income. ..." (warning, also shown under the sign switch) | Two or more rows and not one outflow: a card statement that lists spending as positive numbers, or only one of two amount columns is mapped. | Turn off **Negative values are outflows**, or map Debit and Credit under **More columns**. If the file really holds income only, continue. |
| "N rows are marked as reverted, failed or declined in the file and are left out." (notice) | The Cleared/Status column says the row never happened (Revolut `REVERTED`, `FAILED`, `DECLINED`). | Nothing; those rows did not change the balance. |

## Wrong numbers or signs

- **Amounts 100 times too large or small, or thousands read as decimals**:
  set **Decimal Separator** to match the file (German banks: Comma).
- **Spending imported as income**: the file lists spending as positive
  numbers (card statements). Turn off **Negative values are outflows**. The
  mapping screen warns when every amount would be income.
- **Separate debit/credit columns** (`Soll`/`Haben`, `Debit Amount`/`Credit
  Amount`, `Paid out`/`Paid in`, `Money out`/`Money in`,
  `Withdrawals`/`Deposits`) are mapped as a pair automatically. If your
  bank names them differently, leave Amount on *Ignore* and map Debit and
  Credit under **More columns**. A file with one unsigned amount column and
  an `S`/`H` column maps the latter as the debit/credit flag.
- **Balance off by a fee** (Revolut): the preset maps the `Fee` column; in
  other files map **Fee** under **More columns** when the fee comes on top
  of the amount.
- **Two-digit years** (`18.10.26`, Sparkasse): use `dd.MM.yy`; `dd.MM.yyyy`
  rejects them instead of importing the year 26.

## Header is not the first line

Bank exports that start with account details, a title or a balance before
the column headers (DKB, ING, comdirect, Volksbank, Deutsche Bank) are
handled: the first line that names a date and an amount column (or matches
a bank preset) is the header, and the Configuration card says how many
lines above it were skipped. If the wrong line was taken, delete the lines
above the header in a text editor and import again.

## The file has no header row

Some banks (Targobank) start with the first transaction. The import
recognises this (no line looks like a header and the first line holds a
date and a number), turns on **File has no header row**, names the columns
`#1`, `#2`, ... and guesses Date, Amount and Payee from the values; check
the mapping against the preview. If the first transaction is missing from
the preview or column names show up as a row, flip the switch.

## The date format is not in the list

Tap **Other date format…** under the dropdown and type the pattern: `d`
day, `M` month, `y` year, `H` `m` `s` time, text in single quotes literal
(`d.M.yyyy`, `MMM d, yyyy`, `dd/MM/yyyy 'at' HH:mm`). Month names must be
English. Patterns without separators (`yyyyMMdd`) are not supported.

## My bank's format is not recognised

The **Bank format** dropdown lists the built-in presets (Sparkasse, DKB,
ING, comdirect, N26, Volksbank/Raiffeisenbank, Deutsche Bank, Revolut).
If the headers of a newer export changed, pick the preset by hand or leave
it at "None" and map the columns yourself; the mapping can be saved as an
import profile. Separate debit and credit columns (`Soll`/`Haben`) and a
debit/credit flag column are under **More columns**.

## Garbled characters

Text that is not valid UTF-8 is read as Windows-1252, which covers most
German bank exports (umlauts and the `€` sign). Files in other encodings
(e.g. UTF-16, or Mac Roman) still show wrong characters: save the file as
"CSV UTF-8" and import it again.

## Duplicates

Rows with the same date, amount and payee name as an existing transaction
are marked as duplicates and unchecked on the review screen. The payee is
compared ignoring case and spacing, and the name a rule would set for the
row counts too, so a file imported before a rule renamed its payees is
still recognised. The comparison covers the transactions of the account
chosen at the top of the review screen around the file's date range, and
runs again when you pick another account.

A row with the same amount as an existing transaction of the account at
most 4 days away, whatever its payee, is marked as a *possible* duplicate
and unchecked: the purchase you entered by hand that the bank spells
differently (`UBER *TRIP` vs `Uber Trip`) or books a few days later, or a
transfer you entered by hand. The label names the transaction it matched.
Check the box if it is a separate transaction (two bakery visits for the
same amount in one week look the same to the import). An existing
transaction more than 4 days away is not detected; uncheck such rows by
hand.

## The file names accounts that do not exist

A file with an Account column (the app's own export of several accounts)
whose names do not all match an open account shows a banner listing the
unmatched names, and Import stays disabled until you choose in the Account
dropdown: **Account from file** imports the rows of the matching accounts
and leaves the others out, or pick one account for every row. To import
the left-out rows as well, create or reopen the account under the name the
file uses (or rename it) and import again.

## Imported into the wrong account, or with the wrong sign

Tap **Undo import** in the dialog right after the import, or open
**Import CSV** again and tap **Undo last import**. It deletes the
transactions that import created; rows you edited, categorised or
reconciled since are kept and counted in the confirmation. It is available
until the next import.

## Category not found

A row shows "Category "…" not found – unassigned" when the file's Category
cell names no existing category (the import never creates categories).
Create the category, or rename it to match, and import again; or import the
row without a category and categorize it later. Rules and the payee's
default category still apply to such rows. A category name used in several
groups must be written as `Group: Category` (the app's own export writes
every category that way).

## No account to import into

The import needs an existing account ("Create your first account to get
started with budgeting."). Create one under **Accounts** first.
