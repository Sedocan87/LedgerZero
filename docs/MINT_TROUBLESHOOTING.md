# Mint Migration Troubleshooting

Common issues encountered when importing data from Mint and how to resolve them.

## Import Fails or Hangs

*   **Large Files**: If your `transactions.csv` is very large (>10MB), the import might take a while. LedgerZero processes transactions in batches. Please be patient and keep the app open.
*   **Invalid CSV**: Ensure the file was not modified in Excel in a way that broke the CSV format (e.g., stripping quotes around fields with commas).
*   **Encoding**: The file must be UTF-8 encoded.

## Data Accuracy Issues

### "My Account Balances are Wrong"
Mint exports do **not** contain account balances, only transactions.
*   **Solution**: After import, go to each account in LedgerZero and manually update the "Current Balance" to match your bank. You might need to add a "Starting Balance" adjustment transaction if the history doesn't sum up to the current balance (which is common if history is incomplete).

### "I have duplicate transactions"
LedgerZero attempts to deduplicate based on Date, Amount, and Payee.
*   **Cause**: If you edited the transaction description in Mint but the original import has a different name, it might not match.
*   **Solution**: You can manually delete duplicates in the **Transactions** tab.

### "Categories are messy"
Mint categories are imported as-is.
*   **Solution**: Use the **Budget** screen to move categories into appropriate Groups. You can select "Edit" on a category to change its Group.

## Specific Error Messages

*   **"Invalid Mint CSV format"**: The file is missing required columns (Date, Description, Amount). Ensure you are using the `transactions.csv` export, not a summary report.
*   **"Validation failed"**: The file contains no accounts or transactions.

## Still Stuck?
If you cannot import your data, please verify the file format by opening it in a text editor. It should look like this:

```csv
"Date","Description","Original Description","Amount","Transaction Type","Category","Account Name","Labels","Notes"
"6/09/2020","Safeway","Safeway Store","45.50","debit","Groceries","Chase Checking","",""
```
