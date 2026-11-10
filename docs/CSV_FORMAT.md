# CSV Import Format

LedgerZero imports bank transactions from CSV files. Open it from
**Settings > Manage data > Import CSV**.

Code: `lib/services/csv/csv_import_service.dart` (parsing, header mapping,
validation, conversion, category matching, duplicate check),
`lib/services/csv/csv_date_formats.dart` (date formats and detection),
`lib/services/csv/bank_csv_presets.dart` (bank presets),
`lib/services/csv/decimal_separator_inference.dart`,
`lib/services/import/transaction_import_service.dart` (duplicate check
per account, transfer pairing, commit),
`lib/services/import/import_undo_service.dart` (undo last import),
`lib/core/utils/text_decoding.dart` (encoding), screens in
`lib/presentation/screens/import/`. CSV parsing uses the `csv` package
(6.x). Parsing, format detection, validation and conversion run in
isolates (`parseCsvFile`, `analyzeColumns`, `prepareImport`), not on the UI
thread.

## File

- Extensions offered by the file picker: `.csv`, `.txt`.
- Encoding: UTF-8; a UTF-8 byte order mark is removed. If the file is not
  valid UTF-8 it is decoded as Windows-1252 (the "ANSI" code page of
  Western European Windows, common for German bank exports), so umlauts and
  the euro sign `€` (byte `0x80`) come out right.
- Header line: the first line (of the first 60) that looks like a column
  header, i.e. a bank preset matches it or it names a date column and an
  amount column (or debit and credit columns). Lines above it (account
  details, balances, as DKB, ING, comdirect, Volksbank and Deutsche Bank
  write them) are skipped and the screen says how many. Without such a
  line the first line is the header.
- No header row: when no line looks like a header and the first line
  already holds a date and a number (Targobank), the file is read as
  having no header row. Its columns are named `#1`, `#2`, ... and the
  first line is a transaction. Date, Amount and Payee are then guessed
  from the values (the first column of dates; the first column of numbers
  with a decimal separator or a sign; the longest mostly-text column);
  check them against the preview. The **File has no header row** switch
  shows what was detected and reads the file the other way.
- Delimiter: semicolon, comma or tab, whichever occurs most in the header
  line.
- Row separator: the line break that ends the first record (CRLF, LF or
  CR). A different line break inside a quoted field (a memo with a CRLF in
  an LF file) is part of the field.
- Quoted fields (`"..."`) are supported. Duplicate header names are made
  unique (`Währung`, `Währung (2)`), empty ones become `#n`.
- Blank lines anywhere are dropped. Footer lines such as `Alter Kontostand`
  or `Endsaldo` fail the date check and are skipped (see Validation).

## Bank presets

A preset is recognised from the header names (a fingerprint of required
headers, matched ignoring case) and sets the column mapping, date format,
decimal separator and outflow sign. The **Bank format** dropdown shows the
recognised preset and lets you pick another one or none. Presets are data
(`bankCsvPresets`); each has a synthetic fixture under
`test/fixtures/bank_csv/` that `test/services/csv/bank_presets_test.dart`
imports end to end. Banks without a preset that the header keywords must
handle (Lloyds, Commerzbank, Consorsbank, PayPal, Amex, a Targobank file
without header row) have fixtures under `test/fixtures/bank_csv_generic/`
(`test/services/csv/csv_generic_banks_test.dart`).

| Preset | Fingerprint (required headers) | Date | Notes |
|---|---|---|---|
| Sparkasse (CSV-CAMT) | `Buchungstag`, `Betrag`, `Lastschrift Ursprungsbetrag`, `Beguenstigter/Zahlungspflichtiger` | `dd.MM.yy` | Windows-1252, `;` |
| Sparkasse (CSV-MT940) | `Buchungstag`, `Betrag`, `Kontonummer`, `BLZ`, `Beguenstigter/Zahlungspflichtiger` | `dd.MM.yy` | Windows-1252, `;` |
| DKB | `Buchungsdatum`, `Betrag (€)`, `Zahlungsempfänger*in` | `dd.MM.yy` | preamble; inflows take the payee from `Zahlungspflichtige*r`; `Status` (`Gebucht`/`Vorgemerkt`) sets cleared |
| DKB (before 2023) | `Buchungstag`, `Betrag (EUR)`, `Auftraggeber / Begünstigter` | `dd.MM.yyyy` | preamble |
| ING | `Buchung`, `Valuta`, `Auftraggeber/Empfänger`, `Betrag` | `dd.MM.yyyy` | preamble, two `Währung` columns |
| comdirect | `Buchungstag`, `Wertstellung (Valuta)`, `Umsatz in EUR` | `dd.MM.yyyy` | preamble and footer; the payee is read from `Auftraggeber: X` / `Empfänger: X` inside `Buchungstext` |
| N26 | `Date`, `Payee`, `Amount (EUR)` | `yyyy-MM-dd` | `,`, dot decimal |
| N26 (2024 format) | `Booking Date`, `Partner Name`, `Amount (EUR)` | `yyyy-MM-dd` | `,`, dot decimal |
| Volksbank / Raiffeisenbank | `Buchungstag`, `Name Zahlungsbeteiligter`, `Betrag`, `Verwendungszweck` | `dd.MM.yyyy` | |
| Volksbank / Raiffeisenbank (Umsatz + Soll/Haben) | `Buchungstag`, `Umsatz`, `Soll/Haben` | `dd.MM.yyyy` | unsigned `Umsatz`, `S`/`H` flag; preamble and footer |
| Deutsche Bank | `Buchungstag`, `Umsatzart`, `Soll`, `Haben` | `dd.MM.yyyy` | separate `Soll`/`Haben` columns; preamble and footer |
| Revolut | `Type`, `Product`, `Started Date`, `Description`, `Amount` | `yyyy-MM-dd HH:mm:ss` | `State` (`COMPLETED`/`PENDING`) sets cleared; `REVERTED`, `FAILED` and `DECLINED` rows are left out; `Fee` is charged on top of the amount |

The encoding in the table is informational: decoding is always automatic.
To add a bank, append a `BankCsvPreset` with the headers exactly as the bank
writes them and a small fixture (realistic header, 3–5 synthetic rows).

## Columns

| Field | Required | Notes |
|---|---|---|
| Date | yes | Parsed with the selected date format. |
| Amount | yes* | One signed amount column. |
| Debit / Credit | yes* | Alternative to Amount: separate outflow and inflow columns (`Soll`/`Haben`, `Debit Amount`/`Credit Amount`, `Paid out`/`Paid in`, `Money out`/`Money in`, `Withdrawals`/`Deposits`); amount = \|credit\| − \|debit\|. |
| Debit/credit flag | no | A column whose value marks the row as debit (`S`, `D`, `-`) or credit (`H`, `C`, `+`); it decides the sign of an unsigned amount. |
| Payee | no | Matched to an existing payee by name (case-insensitive) or created. |
| Payee for inflows | no | Used instead of Payee when the amount is positive (banks that split sender and recipient). |
| Memo | no | |
| Category | no | Matched to an existing category by name; see [Categories](#categories). |
| Account | no | The row's account by name; lets the review screen import each row into the account the file names. |
| Transfer | no | The other account of a transfer leg (our own export writes it). |
| Cleared | no | `cleared`/`uncleared`/`reconciled`, yes/no, `Gebucht`/`Vorgemerkt`, `COMPLETED`/`PENDING`; unknown or empty = cleared. Rows whose cell is `REVERTED`, `FAILED` or `DECLINED` never touched the balance: they are left out and counted in a notice before the review. |
| Approved | no | `Yes`/`No` (also true/false, 1/0, ja/nein), as our own export writes it; unknown or empty = approved. |
| Fee | no | A fee charged on top of the amount (Revolut): the row's amount is reduced by it. Only mapped by a preset or by hand. |

\* Either Amount or both Debit and Credit.

Without a preset the columns are mapped from header keywords (English and
German). A header equal to a keyword wins over one containing it as a whole
word, which wins over a mere substring, and each header is used once;
headers containing disqualifying words are skipped for that field
(`Lastschrift Ursprungsbetrag`, `Saldo`, `Währung`, `Gebühr` for Amount;
`IBAN`, `BIC` for Payee). Further rules:

- **Debit/credit pair first.** A pair of outflow and inflow columns is
  looked for before anything else and kept out of the other fields:
  `Debit Amount` contains the word "amount", but read as the one signed
  Amount column it would turn every purchase into income and drop the
  rows whose debit cell is empty (Lloyds, Halifax, Bank of Scotland). A
  file that also has a signed amount column uses that one. A column naming
  both sides (`Soll/Haben`, `Debit/Credit`) is the debit/credit flag.
- **Compound headers.** `Versicherungsbetrag`, `Umsatzsteuer`,
  `Versandkosten`, `...gebühr` and `Entgelt` are not the amount although
  they contain an amount keyword; `Netto` and `Brutto` are (PayPal).
  `Auftraggeberkonto` / `Empfängerkonto` are the other party's account
  number, not a payee, and `Konto #` is not an account name.
- **Payee fallback.** `Name`, `Description`, `Beschreibung` and
  `Buchungstext` are the payee only when no name column matches
  (`Empfänger`, `Auftraggeber`, `Sender / Empfänger`, `Merchant`, ...): in
  a file that has one, `Buchungstext` only holds the booking type
  ("Lastschrift").
- **Payee for inflows** needs a whole-word match (`Zahlungspflichtige*r`,
  `Auftraggeber`, `Sender`). An empty cell in that column leaves the row's
  payee as it is.
- The booking date (`Buchungstag`, `Buchungsdatum`, `Buchung`, `Date`) is
  preferred over the value date (`Valuta`, `Wertstellung`).

The first five fields are on the mapping card, the others under **More
columns**; all can be changed.

## Date formats

`yyyy-MM-dd`, `dd.MM.yyyy`, `dd.MM.yy`, `dd/MM/yyyy`, `MM/dd/yyyy`,
`dd/MM/yy`, `MM/dd/yy`, `yyyy.MM.dd`, `yyyy/MM/dd`, `dd-MM-yyyy`,
`MM-dd-yyyy`, `yyyy-MM-dd HH:mm:ss`, `yyyy-MM-dd'T'HH:mm:ss`,
`dd.MM.yyyy HH:mm`, `dd.MM.yyyy HH:mm:ss`, `dd MMM yyyy`.

A timestamp is read for its calendar day only. For the ISO form
(`2024-02-01T10:00:00Z`) fractional seconds and a zone suffix (`Z`,
`+01:00`) are ignored: the day is the one the file writes, not converted to
another time zone. `MMM` is an English month abbreviation (`01 Feb 2024`).

**Other date format…** under the dropdown takes a pattern typed by hand
(`d` day, `M` month, `y` year, `H`/`m`/`s` time, text in single quotes
literal), for instance `d.M.yyyy` or `MMM d, yyyy`. It is accepted when it
names day, month and year and reads back a date written with it
(`isUsableCsvDateFormat`); patterns without separators such as `yyyyMMdd`
are refused.

Detection (`detectCsvDateFormat`) scores every format over **all** values
of the date column, strictly: the value must have the format's shape (a
`yy` year has exactly two digits, a `yyyy` year four; intl alone would read
`18.10.26` as the year 26), parse strictly (no roll-over of day 31 in
February) and lie in 1900–2100. A format that fits every value wins. When
several do (no day above 12, so `dd/MM/yyyy` and `MM/dd/yyyy` both fit),
the one matching the app language wins (German: day first; English: month
first) and the screen shows the ambiguity under the dropdown; validation
repeats it as a warning. When no format fits every value, the one fitting
most is preselected and the rows it rejects are reported. Two-digit years
use intl's century window (`26` → 2026, `99` → 1999). Imported dates are
stored as UTC midnight of the calendar day.

## Amounts

- Stored as integer minor units (hundredths).
- Both `1,234.56` and `1.234,56` are read. **Decimal Separator** (Dot/Comma)
  resolves ambiguous values such as `1.234` or `1,234`. It is preset from
  the bank preset, else inferred from the amount cells (a cell with both
  separators or with two decimals decides; `inferDecimalSeparator`), else
  from the app language (German: comma).
- Currency symbols and codes before or after the number (`€12,50`,
  `EUR 12.50`), leading or trailing minus (`12,50-`) and accounting
  negatives (`(12.50)`) are accepted.
- **Negative values are outflows** (on by default): a negative amount is
  spending, a positive amount is income. Turn it off for files that list
  spending as positive numbers (credit card statements): the sign of every
  amount is flipped, so charges become outflows and refunds or payments
  (negative in such files) become inflows.
- **Everything would be income.** When two or more rows and not a single
  outflow would be imported, a warning says so under the switch as soon as
  the file is mapped, and again before the review. The usual causes: a card
  statement read with the switch on, or one of two amount columns mapped.

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

**Save Import Profile** stores the column mapping of the five main fields,
date format, decimal separator and outflow setting under a name (table
`import_profiles`, synced like other data). **Load Profile** applies a
saved profile (and switches the bank preset off). Bank presets are built
in and need no profile.

## Validation and review

Before the review screen the file is checked:

- Errors (block the import): Date or Amount (or Debit and Credit) not
  mapped, mapped columns missing from the file, no data rows, and too many
  unreadable rows (see below).
- Warnings (can continue): rows with a date that does not match the format
  or an unreadable amount are **skipped** as long as they are at most 20 %
  of the rows (and at least 3 rows are always tolerated), so a footer line
  or two never blocks a file; above that the same issue is an error, because
  the format or mapping is probably wrong. Further warnings: day and month
  ambiguous (both orders fit every date), dates more than a year from the
  median date (a typo; a long export is not flagged), every amount would be
  income (see Amounts), and the number of rows left out because the file
  marks them as reverted, failed or declined.

The review screen (**Confirm Import**) starts with the target **Account**
and lists the rows with checkboxes, with the matched category or the "not
found" warning under each row.

### Account

- The file has no Account column: the first account is preselected; pick
  another one in the dropdown.
- Every account name of the file matches an open account: **Account from
  file** is preselected. Each row goes into the account it names,
  duplicates are checked per account, and rows whose Transfer column names
  another account of the file are linked as transfers when the opposite leg
  (same day, opposite amount, accounts pointing at each other) is present;
  a leg without counterpart is imported as a normal row.
- Some names match no open account (the account was renamed or closed
  since the export, or the file comes from elsewhere), or some rows have
  an empty Account cell: **nothing is preselected** and Import stays
  disabled. A banner lists the unmatched names. The user chooses either
  **Account from file**, which imports the rows of the matching accounts
  and leaves the others out (each labelled "Account "…" not found – not
  imported"), or one account that takes every row. The file is never put
  into the first account without that choice.

### Duplicates

Two kinds of rows are unchecked and labelled; the user decides. Only the
transactions of the account a row goes into count, and each existing
transaction flags at most one row (two identical coffees in the file
against one stored coffee flag one; with none stored both import).

- **Duplicate**: an existing transaction on the same calendar day with the
  same amount whose payee name equals the row's payee or the payee a rule
  would set for the row, compared trimmed, lower-cased and with collapsed
  spaces (so a re-import after a rule renamed `AMZN MKTP` to `Amazon` is
  still recognised). A row without payee matches an existing transaction
  without payee. This is a re-import of the same bank row.
- **Possible duplicate**: of the existing transactions the first rule left
  over, one with the same amount at most 4 days away
  (`CsvImportService.possibleDuplicateWindowDays`), whatever its payee. This
  is the purchase entered by hand or by quick-add ("Rewe") that the bank
  writes differently ("REWE SAGT DANKE 4711") or books a few days later,
  a payee renamed since, or a hand-entered transfer. The nearest day wins,
  and the label names the transaction that matched ("Possible duplicate:
  Rewe on …").

A regular payment of the same amount that falls within 4 days of an
existing one (two bakery visits) is flagged as a possible duplicate too;
check its box to import it. Changing the account runs the check again; rows
no longer flagged are checked again. **Import** imports all checked rows in
one database transaction.

### Undo last import

The import records the ids of the transactions it created (on this phone,
in the app's preferences; up to 10,000 rows, a larger import is not
recorded). **Undo import** in the dialog shown right after an import, and
**Undo last import** at the top of the import screen until the next
import, delete them again through the same path as deleting transactions
by hand: one database transaction, synced to the other phone, and one
entry on the app's undo stack. Only rows that are still exactly as
imported are deleted. A row that was edited, categorised, reconciled,
split or turned into a transfer since is kept (a transfer as a whole), and
the confirmation says how many. Payees the import created stay. The YNAB
migration has no undo.

### What a row becomes

Each row becomes a transaction, approved and cleared unless the file's
Approved or Cleared column said otherwise. Rules ([RULES.md](RULES.md)) run on every row in
automatic mode (they fill only what the file left empty); when no rule
sets a payee, the payee is matched by name or created, and when neither the
file nor a rule set a category the payee's default category is used.
Transfer legs get no payee and no rules.

## Export and re-import

Transaction CSV export is described in
[BACKUP_AND_EXPORT.md](BACKUP_AND_EXPORT.md): columns `Date`, `Account`,
`Payee`, `Category`, `Memo`, `Amount`, `Cleared`, `Approved`, `Transfer`.
Header names, ISO dates and plain decimal amounts stay English in every app
language: the file is a machine format that scripts and the import read
the same way everywhere. (Report CSV exports are documents for reading and
use the app language.)

`Category` is written as `Group: Category` (the bare name for a category
without group), the form the import needs to tell apart a name that exists
in two groups.

With the app in German the export asks for the variant: **Standard**
(comma-delimited, dot decimals) or **For Excel** (semicolon-delimited,
decimal comma, UTF-8 byte order mark), which a German Excel opens with the
right columns and umlauts. Both have the same columns and both re-import;
for the Excel variant the import detects the semicolon and the decimal
comma by itself.

Exported text cells that start with `=`, `+`, `-`, `@`, a tab or a carriage
return are prefixed with `'` (`lib/services/export/csv_sanitizer.dart`) so
spreadsheets do not evaluate them; the import removes that prefix again
(`CsvSanitizer.unquote`) when the next character is one of those triggers.

An exported file re-imports with the detected settings (`yyyy-MM-dd`, dot
or comma): Account, Transfer, Cleared, Approved and Category map
automatically, **Account from file** puts every row into its account,
transfer legs are linked again, cleared and approved states are kept and
every category is found again, also one whose name exists in two groups
(`test/services/csv/csv_round_trip_test.dart` checks balances, available
amounts and To Be Budgeted are identical).

See also [CSV_TROUBLESHOOTING.md](CSV_TROUBLESHOOTING.md).
