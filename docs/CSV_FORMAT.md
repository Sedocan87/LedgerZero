# CSV Import Format

LedgerZero imports bank transactions from CSV files into one account at a
time. Open it from **Settings > Manage data > Import CSV**.

Code: `lib/services/csv/csv_import_service.dart` (parsing, validation,
conversion, category matching), `lib/services/import/transaction_import_service.dart`
(duplicate check, commit), `lib/core/utils/text_decoding.dart` (encoding), screens in `lib/presentation/screens/import/`. CSV parsing uses the
`csv` package (6.x).

## File

- Extensions offered by the file picker: `.csv`, `.txt`.
- Encoding: UTF-8; a UTF-8 byte order mark is removed. If the file is not
  valid UTF-8 it is decoded as Windows-1252 (the "ANSI" code page of
  Western European Windows, common for German bank exports), so umlauts and
  the euro sign `€` (byte `0x80`) come out right.
- Delimiter: comma or semicolon, detected from the first line (whichever
  occurs more often). Tab-separated files are not supported.
- Quoted fields (`"..."`) are supported.
- The **first row must be the header row**. Bank exports that put account
  information or other text above the header must be trimmed first.

## Columns

| Field | Required | Notes |
|---|---|---|
| Date | yes | Parsed with the selected date format. |
| Amount | yes | One signed amount column. |
| Payee | no | Matched to an existing payee by name (case-insensitive) or created. |
| Memo | no | |
| Category | no | Matched to an existing category by name; see [Categories](#categories). |

Columns are mapped automatically from header keywords (English and German,
e.g. `Date`/`Buchungstag`/`Valuta`, `Amount`/`Betrag`/`Umsatz`,
`Payee`/`Description`/`Empfänger`/`Auftraggeber`, `Memo`/`Verwendungszweck`)
and can be changed on the mapping card. Separate debit and credit columns are
not supported.

## Date formats

`yyyy-MM-dd`, `MM/dd/yyyy`, `dd/MM/yyyy`, `yyyy.MM.dd`, `dd.MM.yyyy`,
`MM-dd-yyyy`. The format is guessed from the first rows of the date column;
check it, because `01/02/2024` matches both `MM/dd/yyyy` and `dd/MM/yyyy`.
Imported dates are stored as UTC midnight of the calendar day.

## Amounts

- Stored as integer minor units (hundredths).
- Both `1,234.56` and `1.234,56` are read. **Decimal Separator** (Dot/Comma)
  resolves ambiguous values such as `1.234` or `1,234`.
- Currency symbols and codes before or after the number (`€12,50`,
  `EUR 12.50`), leading or trailing minus (`12,50-`) and accounting
  negatives (`(12.50)`) are accepted.
- **Negative values are outflows** (on by default): a negative amount is
  spending, a positive amount is income. Turn it off for files that list
  spending as positive numbers (credit card statements): the sign of every
  amount is flipped, so charges become outflows and refunds or payments
  (negative in such files) become inflows.

## Categories

When a Category column is mapped, each cell is matched to an existing
category, ignoring case and surrounding or repeated spaces. A cell can name
the category alone (`Groceries`) or with its group (`Food: Groceries`). A
category name that exists in more than one group only matches in the
`Group: Category` form. Categories are never created by the import: rows
whose category is not found are shown on the review screen with a warning
("Category "…" not found – unassigned") and imported without that category.
Empty cells mean "no category from the file".

Which category a row gets (first match wins):

1. The category from the file's Category column, when it matched.
2. A rule's "set category" action ([RULES.md](RULES.md)); rules never
  override a category the file supplied.
3. The payee's default category.

## Import profiles

**Save Import Profile** stores the column mapping, date format, decimal
separator and outflow setting under a name (table `import_profiles`, synced
like other data). **Load Profile** applies a saved profile. There are no
built-in bank presets.

## Validation and review

Before the review screen the file is checked:

- Errors (block the import): Date or Amount not mapped, mapped columns
  missing from the file, dates that do not match the selected format.
- Warnings (can continue): unreadable amounts (those rows are skipped),
  dates more than 60 days from the median date.

The review screen (**Confirm Import**) starts with the target **Account**
(the first open account is preselected) and lists the rows with checkboxes,
with the matched category or the "not found" warning under each row.
Possible duplicates (same date, amount and payee name as an existing
transaction of the chosen account in the file's date range) are marked and
unchecked. Changing the account runs the check again for the new account;
rows that are no longer duplicates are checked again. **Import** imports
all checked rows into the chosen account in one database transaction.

Each row becomes a cleared, approved transaction. Rules
([RULES.md](RULES.md)) run on every row in automatic mode (they fill only
what the file left empty); when no rule sets a payee, the payee is matched
by name or created, and when neither the file nor a rule set a category the
payee's default category is used.

## Export

Transaction CSV export is described in
[BACKUP_AND_EXPORT.md](BACKUP_AND_EXPORT.md). Exported text cells that start
with `=`, `+`, `-`, `@`, a tab or a carriage return are prefixed with `'`
(`lib/services/export/csv_sanitizer.dart`) so spreadsheets do not evaluate
them; dates and amounts are written as plain values. An exported file can be
imported again with the default settings (`yyyy-MM-dd`, dot); all rows go
into the one account selected at import.

See also [CSV_TROUBLESHOOTING.md](CSV_TROUBLESHOOTING.md).
