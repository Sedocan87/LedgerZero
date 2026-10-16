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
| "N rows have dates that do not match the format ..." | Wrong **Date Format**. | Pick the format that matches the file (e.g. `dd.MM.yyyy` for German banks). |
| "N rows have unreadable amounts and will be skipped." (warning) | The amount cell is empty or not a number. | Check the Amount mapping and the **Decimal Separator**. You can continue; those rows are left out. |
| "N dates are far from the others..." (warning) | Some dates are more than 60 days from the median, e.g. a wrong day/month order or a file covering several months. | Check the dates on the review screen. |

## Wrong numbers or signs

- **Amounts 100 times too large or small, or thousands read as decimals**:
  set **Decimal Separator** to match the file (German banks: Comma).
- **Spending imported as income**: the file lists spending as positive
  numbers. Turn off **Negative values are outflows**.
- **Separate debit/credit columns**: not supported. Combine them into one
  signed Amount column in a spreadsheet first.

## Header is not the first line

Some bank exports start with account details or a title before the column
headers. LedgerZero always uses the first row as the header. Delete the lines
above the header in a text editor or spreadsheet and save as CSV.

## Garbled characters

Text that is not valid UTF-8 is read as Windows-1252, which covers most
German bank exports (umlauts and the `€` sign). Files in other encodings
(e.g. UTF-16, or Mac Roman) still show wrong characters: save the file as
"CSV UTF-8" and import it again.

## Duplicates

Rows with the same date, amount and payee name as an existing transaction
are marked as possible duplicates and unchecked on the review screen. The
comparison covers the transactions of the account chosen at the top of the
review screen in the file's date range, and runs again when you pick another
account. A
payee spelled differently by the bank (e.g. `UBER *TRIP` vs `Uber Trip`) is
not detected; uncheck such rows by hand.

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
