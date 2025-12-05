# CSV Import Troubleshooting Guide

If you are encountering issues importing your CSV file into LedgerZero, please review the common problems and solutions below.

## Common Error Messages

### "File content not available"
- **Cause**: The file might be corrupted or inaccessible by the operating system.
- **Solution**: Try opening the file in a text editor or spreadsheet app to verify it is valid. Re-download it from your bank.

### "No data found in the CSV file"
- **Cause**: The file is empty or contains only a header row.
- **Solution**: Verify the file has transaction data.

### "Mapped columns not found in CSV headers"
- **Cause**: The column names you selected in the mapping screen do not match the headers in your file.
- **Solution**: Re-check your column mapping. Note that column names are case-sensitive.

### "Rows have invalid dates"
- **Cause**: The date format in the file does not match the format selected in LedgerZero (e.g., file has `MM/dd/yyyy` but you selected `dd.MM.yyyy`).
- **Solution**: Check the file content and select the matching format in the import settings.

### "Rows have invalid amounts"
- **Cause**: The amount column contains non-numeric characters that couldn't be cleaned, or the decimal separator is incorrect (e.g., using comma for decimals when dot is expected).
- **Solution**: Ensure you selected the correct decimal separator (Dot vs Comma).

## Encoding Issues (Garbage Characters)
- **Symptoms**: Special characters (like accents or currency symbols) appear as random symbols (e.g., `Ã©` instead of `é`).
- **Cause**: The file is encoded in a format other than UTF-8 (commonly ISO-8859-1 or Windows-1252).
- **Solution**: LedgerZero automatically attempts to detect Latin-1 encoding. If issues persist, try saving the file as "CSV (UTF-8)" in Excel or a text editor before importing.

## Duplicate Transactions
- **Issue**: Transactions you've already imported appear again.
- **Solution**: LedgerZero automatically flags duplicates based on Date, Amount, and Payee. Ensure these fields match exactly. If a bank changes the Payee name slightly (e.g., "UBER *TRIP" vs "Uber Trip"), it may be seen as a new transaction. You can manually uncheck duplicates before confirming the import.

## Bank-Specific Notes

- **Chase**: Select `MM/dd/yyyy` date format. Map 'Posting Date' to Date, 'Amount' to Amount, and 'Description' to Payee.
- **Wells Fargo**: Often has 5 columns. Map the 5th column to Payee/Description.
- **Citibank**: Might split Debit and Credit into separate columns. Currently, LedgerZero requires a single Amount column (negative for outflow). You may need to merge them in a spreadsheet first.

## Need More Help?
If you continue to have issues, please contact support with a sample of your CSV file (remove sensitive account numbers first).
