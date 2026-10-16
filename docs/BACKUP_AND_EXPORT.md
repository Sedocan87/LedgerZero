# Backup and Export Procedures

LedgerZero prioritizes data sovereignty. This means you have full control over your financial data. We provide multiple ways to backup, export, and port your data.

## 1. Full Database Backup

A full backup is a snapshot of your entire database (accounts, transactions,
budgets, rules, settings stored in the database). It is the recommended way
to protect your data against loss.

### How to Create a Backup
1. Navigate to **Settings > Backup & Export**.
2. Under **Create backup**, choose a **backup password** (at least 10
   characters) and confirm it.
3. Optionally turn on **Also upload to your sync storage** (only available
   when Google Drive or iCloud sync is set up). A failed upload is reported;
   the backup is still created.
4. Tap **Export backup** and use the share sheet to save the `.lzbk` file
   (e.g. to Files, a computer or a USB drive). The temporary copy inside the
   app is deleted afterwards.

### Encryption
Backups are **always** encrypted: AES-256-GCM with a key derived from the
backup password by Argon2id (fresh random salt per backup). There is no
unencrypted backup option. If you need a readable copy, use the JSON or CSV
export below. Details: [BACKUP_FORMAT.md](BACKUP_FORMAT.md).

**Important:** without the backup password the backup cannot be restored.

### Compression
Backups are compressed with gzip before encryption.

## 2. Restore

### How to Restore
1. Navigate to **Settings > Backup & Export**.
2. Under **Restore backup**, tap **Restore from file** and pick a `.lzbk` file.
3. Confirm that all data on this device will be replaced, then enter the
   backup password.
4. The backup is checked, upgraded if it comes from an older version, and
   re-encrypted with this device's key. The app reopens the data directly;
   no restart is needed. If anything fails, your current data is kept.
5. If you use sync, the device resynchronises after a restore: changes made
   on your other devices after the backup was created will sync back in.

**Merge transactions from a backup (date range)** copies the transactions of
a date range (and any missing accounts, categories and payees) into the
current data without replacing it.

## 3. Data Portability (JSON Export)

For interoperability with other software or for your own analysis, you can export your entire dataset in JSON format.

### How to Export to JSON
1. Navigate to **Settings > Backup & Export**.
2. Under **Export**, tap **All data (JSON)**.
3. Use the share sheet to save the file or send it to another app.

The JSON file contains a `metadata` object (`version` `2.0`,
`amount_unit` `minor`: every amount is an integer of minor units, dates are
UTC ISO-8601) and arrays for:
- `accounts`
- `transactions`
- `categories`
- `category_groups`
- `payees`
- `budgets`
- `scheduled_transactions`

JSON and CSV exports are **not** encrypted.

## 4. Transaction Export (CSV)

You can export transactions to CSV for use in spreadsheet applications like Excel, Google Sheets, or LibreOffice Calc.

### How to Export Transactions
1. **Global Export:** Go to **Settings > Backup & Export** and tap **All transactions (CSV)**. This exports all transactions from all accounts.
2. **Account Specific:** Go to an Account's detail screen, tap the menu (three dots), and select **Export to CSV**.
3. **Filtered Export:** In **Settings > Backup & Export**, tap **Filtered transactions (CSV)** and choose dates, accounts and categories.

### CSV Format
The CSV file includes the following columns:
- `Date` (YYYY-MM-DD)
- `Account`
- `Payee`
- `Category`
- `Memo`
- `Amount` (plain decimal in major units, e.g. `-12.50`)
- `Cleared`
- `Approved` (`Yes`/`No`)

Header names stay English in every app language. A split transaction is
exported as its lines (the parent row is left out).

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
2. Tap **Backup reminder**.
3. Select your preferred frequency: Daily, Weekly, Monthly, or Never
   (default: Weekly).

Note: LedgerZero does not currently perform background backups automatically due to OS restrictions on accessing user file storage without interaction. The reminder notification will prompt you to open the app and initiate a backup.
