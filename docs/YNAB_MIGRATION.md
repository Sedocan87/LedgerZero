# YNAB Migration Guide

LedgerZero makes it easy to migrate your financial history from You Need A Budget (YNAB). We support importing from both the modern web-based YNAB (nYNAB) and the classic YNAB 4 desktop application.

## Prerequisites

- **nYNAB**: You need to export your budget data from the YNAB web interface.
  - Go to **My Budget** -> **Export Budget**.
  - This will download a zip file containing `Register.csv` and `Budget.csv`. Extract these files.
- **YNAB 4**: You need access to your `.ynab4` data folder (e.g., inside your Dropbox or local documents).

## Step-by-Step Migration

1. **Navigate to Migration Tool**:
   - Open LedgerZero.
   - Go to **Settings** -> **Import Data** -> **YNAB Migration**.

2. **Select YNAB Version**:
   - Choose **nYNAB (CSV Export)** if you are coming from the subscription-based YNAB.
   - Choose **YNAB 4 (Classic)** if you are using the older desktop version.

3. **Select Files**:
   - **For nYNAB**:
     - Tap "Select Register.csv" and pick the file from your extracted export.
     - Tap "Select Budget.csv" and pick the file.
   - **For YNAB 4**:
     - Tap "Select Budget Folder" and choose your `.ynab4` directory.

4. **Preview Data**:
   - LedgerZero will parse your files and display a summary.
   - **Accounts**: Review the list of accounts that will be created or merged.
   - **Categories**: Review the category groups and categories.
   - **Stats**: Check the total number of transactions and budget entries.

5. **Import**:
   - Tap **Confirm & Import**.
   - The app will process your data. This may take a few moments for large budgets.
   - **Do not close the app** during this process.

6. **Success**:
   - Once complete, you will see a success screen with a summary of imported items.
   - Click **Start Budgeting** to view your migrated data.

## What gets imported?

- **Accounts**: All open and closed accounts. Types are mapped to LedgerZero equivalents (e.g., Checking, Savings, Credit Card).
- **Categories**: Category Groups and Categories. Hidden categories are imported but marked hidden.
- **Transactions**: All transactions, including splits and transfers.
- **Payees**: Payees are created and linked to transactions.
- **Scheduled Transactions**: Recurring transactions are imported.
- **Budget History**: Historical budgeted amounts are imported for nYNAB. (Note: Goal import is currently limited).

## FAQ (Task 550)

**Q: Will this duplicate my data if I run it twice?**
A: LedgerZero attempts to match existing accounts and categories by name. However, transactions are imported as new. Running the import multiple times on the same file may result in duplicate transactions. It is recommended to start with a fresh LedgerZero database or use the "Undo" feature if something goes wrong immediately.

**Q: My "Credit Card Payment" categories are missing.**
A: LedgerZero handles credit cards differently than YNAB. We do not use special payment categories. Transfers to credit card accounts are treated as simple transfers.

**Q: How are split transactions handled?**
A: Split transactions are fully supported. They appear as a parent transaction with multiple splits in your ledger.

**Q: What happens to my Goals?**
A: Currently, YNAB Goals are not imported directly. You will need to set up goals in LedgerZero manually.

**Q: Why do I see "Uncategorized" transactions?**
A: If a category was deleted or hidden in YNAB but still has transactions, they might appear as Uncategorized. You can reassign them in LedgerZero.

**Q: Does it support multi-currency?**
A: LedgerZero supports multi-currency accounts, but the YNAB import assumes the currency of the export file. If you have a multi-budget setup in YNAB, import each budget separately into separate LedgerZero profiles (if supported) or carefully manage them.

## Troubleshooting

- **"Invalid CSV Format"**: Ensure you are using the official export from YNAB. Do not open and save the CSV in Excel before importing, as it may change the date formats.
- **Missing Data**: Check if you selected the correct files. The `Register.csv` contains transactions, and `Budget.csv` contains budget allocations. Both are required for nYNAB.

For further assistance, contact support@ledgerzero.app.
