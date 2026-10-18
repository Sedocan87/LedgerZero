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

## Wrong numbers or signs

- **Amounts 100 times too large or small, or thousands read as decimals**:
  set **Decimal Separator** to match the file (German banks: Comma).
- **Spending imported as income**: the file lists spending as positive
  numbers. Turn off **Negative values are outflows**.
- **Separate debit/credit columns** (`Soll`/`Haben`): leave Amount on
  *Ignore* and map Debit and Credit under **More columns**. A file with one
  unsigned amount column and an `S`/`H` column maps the latter as the
  debit/credit flag.
- **Two-digit years** (`18.10.26`, Sparkasse): use `dd.MM.yy`; `dd.MM.yyyy`
  rejects them instead of importing the year 26.

## Header is not the first line

Bank exports that start with account details, a title or a balance before
the column headers (DKB, ING, comdirect, Volksbank, Deutsche Bank) are
handled: the first line that names a date and an amount column (or matches
a bank preset) is the header, and the Configuration card says how many
lines above it were skipped. If the wrong line was taken, delete the lines
above the header in a text editor and import again.

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
chosen at the top of the review screen in the file's date range, and runs
again when you pick another account. A row whose date and amount match an
existing transaction without payee (a transfer you entered by hand) is
marked as a *possible* duplicate and unchecked; check it if it is a
different transaction. A payee spelled differently by the bank (e.g.
`UBER *TRIP` vs `Uber Trip`) is not detected; uncheck such rows by hand.

## Category not found

A row shows "Category "…" not found – unassigned" when the file's Category
cell names no existing category (the import never creates categories).
Create the category, or rename it to match, and import again; or import the
row without a category and categorize it later. Rules and the payee's
default category still apply to such rows. A category name used in several
groups must be written as `Group: Category`.

## No account to import into

The import needs an existing account ("Create your first account to get
started with budgeting."). Create one under **Accounts** first.
