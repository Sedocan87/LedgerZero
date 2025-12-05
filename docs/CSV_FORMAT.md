# CSV Import Format Guide

LedgerZero supports importing transactions from various banks and financial institutions via CSV (Comma-Separated Values) files. This guide explains the required format and configuration options.

## Supported File Types

- **Format**: `.csv`
- **Encoding**: UTF-8 (preferred) or ISO-8859-1 (Latin-1)
- **Delimiters**: Comma (`,`) or Semicolon (`;`) - Automatically detected

## Required Columns

You must map the following columns during the import process:

| Column Name | Description | Example |
|---|---|---|
| **Date** | The date of the transaction. | `2023-01-25`, `01/25/2023` |
| **Amount** | The transaction amount. | `-45.50`, `1200.00` |

### Optional Columns

| Column Name | Description | Example |
|---|---|---|
| **Payee** | The name of the merchant or person. | `Target`, `Starbucks` |
| **Memo** | Additional notes or description. | `Groceries`, `Coffee` |
| **Category** | *Not typically used in bank exports, but supported if available.* | `Food`, `Income` |

## Date Formats

The importer supports common date formats. You must specify the format that matches your CSV file during import:

- `yyyy-MM-dd` (e.g., 2023-12-31) - *Recommended*
- `MM/dd/yyyy` (e.g., 12/31/2023) - Common in US
- `dd/MM/yyyy` (e.g., 31/12/2023) - Common in Europe
- `dd.MM.yyyy` (e.g., 31.12.2023) - Common in Germany

## Amount Handling

- **Decimal Separator**: Both dot (`.`) and comma (`.`) are supported (e.g., `10.50` or `10,50`). You must select the correct one in settings.
- **Currency Symbols**: Symbols like `$`, `€`, `£` are automatically stripped.
- **Sign Convention**:
  - **Outflow is Negative** (Default): `-50.00` is spending, `1000.00` is income.
  - **Invert Signs**: Some banks export spending as positive numbers. Use the "Outflow is positive" toggle during import to flip the signs.

## Troubleshooting

If your file fails to import:
1. Ensure the file is a valid CSV.
2. Check that the header row exists.
3. Verify that the Date format matches the selected option.
4. Ensure the file encoding is standard text (not binary).

See `docs/CSV_TROUBLESHOOTING.md` for more details.
