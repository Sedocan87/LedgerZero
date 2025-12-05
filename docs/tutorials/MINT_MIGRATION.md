# Mint Migration Tutorial

Migrating from Mint to LedgerZero is a straightforward process. This guide will walk you through exporting your data from Mint (if you have an archive) and importing it into LedgerZero.

## Prerequisites

*   A Mint export file (`transactions.csv`).
*   LedgerZero installed on your device.

## Step 1: Prepare Your Mint Export

If you haven't already exported your data from Mint (before it shut down), you might need to check if you have a backup of your `transactions.csv` file.

1.  Locate your `transactions.csv` file.
2.  Ensure it is a standard CSV file with headers like `Date`, `Description`, `Amount`, `Transaction Type`, `Category`, `Account Name`, etc.

## Step 2: Import into LedgerZero

1.  Open LedgerZero.
2.  Navigate to **Settings** (gear icon).
3.  Scroll down to the **Import/Export** section.
4.  Tap on **Import from Mint**.
5.  Tap **Select File** and choose your `transactions.csv` file.

## Step 3: Review and Confirm

LedgerZero will parse your file and show a progress bar.

*   **Accounts**: LedgerZero will create accounts based on the "Account Name" column in your CSV.
*   **Categories**: LedgerZero will try to match Mint categories to existing LedgerZero categories. If no match is found, it will create new categories under a "Mint Import" group.
*   **Transactions**: All transactions will be imported. Duplicates (same date, amount, and similar details) will be automatically skipped.

## Step 4: Post-Migration Cleanup

After the import is complete:

1.  **Check Accounts**: Go to the **Accounts** tab. You might want to rename accounts or set their correct types (Checking, Savings, Credit Card) if they were inferred incorrectly.
2.  **Organize Categories**: Go to the **Budget** tab. You will likely see a "Mint Import" category group. You can move these categories into your preferred structure and delete the empty group.
3.  **Reconcile Balances**: Since the export only contains transactions and not current balances, you will need to manually update the "Current Balance" of your accounts to match your actual bank balances.

## Troubleshooting

*   **File Format Error**: Ensure your file is a valid CSV.
*   **Missing Data**: If some transactions are missing, check if they were flagged as duplicates.
*   **Future Dates**: LedgerZero will warn you if your import contains transactions with future dates.

For more help, see [Mint Troubleshooting](MINT_TROUBLESHOOTING.md).
