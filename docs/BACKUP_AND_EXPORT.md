# Backup and Export Procedures

LedgerZero prioritizes data sovereignty. This means you have full control over your financial data. We provide multiple ways to backup, export, and port your data.

## 1. Full Database Backup

A full backup creates a snapshot of your entire database, including all accounts, transactions, budgets, and settings. This is the recommended method for securing your data against loss.

### How to Create a Backup
1. Navigate to **Settings > Backup & Export**.
2. Tap **Create Full Backup**.
3. If you have enabled encryption (recommended), the backup file will be encrypted with your master password.
4. The backup file (ending in `.lzbk` for encrypted or `.sqlite` for unencrypted) is saved to your device's document storage.
5. We strongly recommend uploading this file to a secure cloud storage provider or transferring it to another device.

### Encryption
Encrypted backups use **AES-GCM (256-bit)** encryption. The key is derived from your master password using **PBKDF2** with a unique salt for each backup.
**Important:** If you lose your master password, you cannot restore an encrypted backup.

### Compression
Backups are automatically compressed using GZIP before encryption to minimize file size.

## 2. Restore

### How to Restore
1. Navigate to **Settings > Backup & Export**.
2. Tap **Restore Backup**.
3. Select the backup file (`.lzbk` or `.sqlite`) from your file system.
4. If the backup is encrypted, you will be prompted to enter the password used when the backup was created.
5. **Warning:** Restoring a backup will overwrite your current database. Ensure you have backed up your current data if you wish to save it.

## 3. Data Portability (JSON Export)

For interoperability with other software or for your own analysis, you can export your entire dataset in JSON format.

### How to Export to JSON
1. Navigate to **Settings > Backup & Export**.
2. Tap **Export All Data (JSON)**.
3. Use the share sheet to save the file or send it to another app.

The JSON file contains arrays for:
- `accounts`
- `transactions`
- `categories`
- `payees`
- `budgets`
- `scheduled_transactions`

## 4. Transaction Export (CSV)

You can export transactions to CSV for use in spreadsheet applications like Excel, Google Sheets, or LibreOffice Calc.

### How to Export Transactions
1. **Global Export:** Go to **Settings > Backup & Export** and tap **Export Transactions (CSV)**. This exports all transactions from all accounts.
2. **Account Specific:** Go to an Account's detail screen, tap the menu (three dots), and select **Export to CSV**.
3. **Filtered Export:** (Coming soon) From the Transactions list, filter your view and export only visible transactions.

### CSV Format
The CSV file includes the following columns:
- Date (YYYY-MM-DD)
- Account Name
- Payee Name
- Category Name
- Memo
- Amount
- Cleared Status
- Approved Status

## 5. Report Exports

You can export charts and reports as images or PDF documents.

### How to Export Reports
1. Navigate to the **Reports** tab.
2. Select the report you wish to view (e.g., Spending Trends).
3. Tap the **Export** icon in the app bar.
4. Choose your desired format:
   - **PDF:** Generates a document with the chart data in a table.
   - **Image:** Captures the current chart as a PNG image.
   - **CSV:** Exports the underlying data points to CSV.

## 6. Automatic Backups

LedgerZero can remind you to backup your data regularly.

### Configure Reminders
1. Navigate to **Settings > Backup & Export**.
2. Tap **Backup Frequency**.
3. Select your preferred frequency: Daily, Weekly, Monthly, or Never.

Note: LedgerZero does not currently perform background backups automatically due to OS restrictions on accessing user file storage without interaction. The reminder notification will prompt you to open the app and initiate a backup.
