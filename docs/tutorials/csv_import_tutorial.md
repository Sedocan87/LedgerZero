# Video Tutorial Script: Importing a Bank CSV

**Duration**: about 2 minutes
**Format**: phone screen recording with voiceover
Reference: [CSV_FORMAT.md](../CSV_FORMAT.md)

## 1. Introduction (0:00 - 0:15)
**Visual**: LedgerZero Home screen.
**Audio**: "This video shows how to import transactions from your bank's CSV
export instead of entering them by hand."

## 2. Get the CSV (0:15 - 0:30)
**Visual**: A CSV file opened in a spreadsheet (generic sample data).
**Audio**: "Download your transactions from online banking as CSV. The first
line must be the column headers, with at least a date and an amount column."

## 3. Pick the file (0:30 - 0:45)
**Action**: Gear icon on Home > **Settings** > **Manage data** >
**Import CSV**. Pick the file.
**Audio**: "Open Settings and tap Import CSV under Manage data, then pick
your file."

## 4. Configure and map (0:45 - 1:20)
**Visual**: The **Configuration** card (Date Format, Decimal Separator,
**Negative values are outflows**), the **Column Mapping** card and the
**Preview** table.
**Audio**: "LedgerZero maps the columns and guesses the date format. Check
Date and Amount, and optionally Payee, Memo and Category. Categories are
matched to your existing categories by name; nothing new is created. For German banks, choose the
comma as decimal separator. If your bank shows spending as positive
numbers, switch off 'Negative values are outflows'. Save the settings as an
import profile; next time, load it with the profile icon."
**Action**: Tap the save icon, name the profile.

## 5. Review and import (1:20 - 1:50)
**Visual**: **Confirm Import** with the **Account** field on top; a row
marked as a possible duplicate is unchecked; a row whose category was not
found shows a warning.
**Action**: Choose the account, uncheck a row, tap **Import**.
**Audio**: "Choose the account first: possible duplicates of that
account's transactions are marked and unchecked, and the check runs again
if you pick another account. Then tap Import."

## 6. Result (1:50 - 2:00)
**Visual**: "Import Successful" dialog, then the transaction list.
**Audio**: "Your rules and payee default categories were applied during the
import. Categorize the rest in the transaction list."
