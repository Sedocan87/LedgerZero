# Backup and Export Procedures

LedgerZero prioritizes data sovereignty. This means you have full control over your financial data. We provide multiple ways to backup, export, and port your data.

## 1. Full Database Backup

A full backup is a snapshot of your entire database (accounts, transactions,
budgets, categories, payees, scheduled transactions, rules, import profiles,
report notes and the local sync state). App settings live in the phone's
preferences and are not part of it. It is the recommended way to protect
your data against loss.

**Your budget lives on this phone.** If the phone is lost or reset, the
budget is gone, unless Android backup is on (section 7), a backup file is
kept somewhere else (a computer, a USB stick, a cloud folder) or a second
phone syncs with this one. The database on the phone is not encrypted by
the app (it is protected by Android's app sandbox and your screen lock);
backup files and sync files are encrypted with your password or
passphrase, and Android backup is end-to-end encrypted by Android with the
screen lock. The Backup screen and onboarding say so.

**Personal accounts:** the transactions of your personal accounts never
sync to the other phone, so they exist only on this phone and in this
phone's backups. The Backup screen reminds you of this and shows a
"Back up now" notice when you have personal accounts and the last backup
is older than 7 days (or there is none).

**Sync key:** a backup contains the derived sync key. Anyone with the
backup file *and* its password can read the household's sync folder.

### How to Create a Backup
1. Navigate to **Settings > Backup & Export**.
2. Under **Create backup**, choose a **backup password** (at least 10
   characters) and confirm it.
3. Tap **Save to…** and pick where the `.lzbk` file goes in Android's
   file picker: a folder on the phone, a USB stick, or a cloud app such as
   Google Drive or Dropbox (installed cloud apps appear there; the app you
   pick does the upload, LedgerZero signs in to nothing). Or tap
   **Share…** to hand it to another app (mail, messenger, Files).
4. The temporary copy inside the app is deleted afterwards. "Last backup"
   (for the reminder) is recorded only when the file was saved (the picker
   was not cancelled) or the share sheet was not dismissed.

### Encryption
Backups are **always** encrypted: AES-256-GCM with a key derived from the
backup password by Argon2id (fresh random salt per backup). There is no
unencrypted backup option. If you need a readable copy, use the JSON or CSV
export below. Details: [BACKUP_FORMAT.md](BACKUP_FORMAT.md).

**Important:** without the backup password the backup cannot be restored.

### Compression
Backups are compressed with gzip before encryption.

## 1b. Automatic backups

**Settings > Backup & Export > Automatic backups** keeps an encrypted
backup on the phone without you doing anything:

* Turn it on with a backup password (the same rules as a manual backup
  password). The first backup is made right away; afterwards one is made
  once a day, when the app starts or comes back to the foreground. After a
  failure the app tries again an hour later and the switch shows the error.
* The files are ordinary `.lzbk` backups named
  `ledgerzero_auto_<date>_<time>.lzbk` in the app's external files folder
  (`Android/data/com.ledgerzero.app/files/backups`, reachable over USB and
  in file managers; the Backup screen shows the exact path). The last 7
  are kept.
* They are what you restore from when the database on the phone cannot be
  opened any more (a damaged file): the automatic backups still open with
  their password (see [ERROR_RECOVERY.md](ERROR_RECOVERY.md), section 3).
  A factory reset of the app keeps them for that reason; **Delete the automatic backups**
  removes them.
* They do **not** survive a lost phone, a factory reset of the phone or an
  uninstall. Copy the folder to a computer now and then, or export a
  backup through the share sheet.
* The password is stored in the phone's secure storage so the backups can
  run unattended. Turning the feature off forgets it; the files stay. If
  the secure storage loses it (the key store was reset) or the app moved
  to a new phone (the stored password does not move along), the switch
  says "The backup password is no longer stored on this phone": turn the
  feature off and on again to enter it.
* An automatic backup does **not** count as a backup for the reminder
  (section 6) or for the "Back up now" nudge shown while personal
  accounts exist: the file is on the phone and is lost with it. Both keep
  counting from the last backup that left the phone. (Earlier versions
  recorded it as the last backup; such a stamp is dropped once after the
  update.)

**Restore an automatic backup** in the Restore section lists them newest
first and then runs the normal restore (confirmation, password, warnings).

## 2. Restore

### How to Restore
1. Navigate to **Settings > Backup & Export**.
2. Under **Restore backup**, tap **Restore from file** and pick a `.lzbk` file.
3. Confirm that all data on this device will be replaced, then enter the
   backup password.
4. The backup is checked and, before anything is replaced, you are warned
   when
   * it belongs to **another household member** (its member id differs
     from this phone's while this phone has a member id or shows personal
     accounts): afterwards the personal accounts in the backup are yours
     and the accounts that are yours now become your partner's, with their
     transactions gone from this phone;
   * it is **older than 180 days**: items deleted on another phone since
     then may come back, because sync no longer remembers those deletions.
5. The backup replaces the database. Backups of development builds before
   schema v20 are refused ("made by an early test version"). The app
   reopens the data directly;
   no restart is needed. If anything fails, your current data is kept; if
   the app is killed in the middle, the next start finishes the restore.
6. If you use sync, the device resynchronises after a restore: changes made
   on your other devices after the backup was created will sync back in.
   So do this phone's own changes that were already synced: the sync
   folder still has them, and they are applied again under the conflict
   rule. A restore therefore brings back data that was lost; it does
   **not** undo a mistake that has already synced (a deleted account, a
   bad import), and there is no "replace the shared budget with this
   backup". While a sync provider is set, the confirmation dialog says
   so.

**Merge transactions from a backup (date range)** copies the transactions of
a date range — together with the other leg of a transfer and the parts of
a split — and any missing accounts, categories and payees into the current
data without replacing it. Transactions in your partner's personal
accounts are left out. The merged rows count as new edits and sync to the
other phone.

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
- `Category` (`Group: Category`, so a name used in two groups re-imports)
- `Memo`
- `Amount` (plain decimal in major units, e.g. `-12.50`; `-12,50` in the
  Excel variant)
- `Cleared` (`cleared`, `uncleared`, `reconciled`)
- `Approved` (`Yes`/`No`)
- `Transfer` (the other account of a transfer leg, else empty)

Header names stay English in every app language: the file is a machine
format that re-imports losslessly (see [CSV_FORMAT.md](CSV_FORMAT.md),
"Export and re-import"). Report CSVs (section 5) are documents for
reading and use the app language instead. A split transaction is exported
as its lines (the parent row is left out).

With the app in German each of the three exports first asks for the
variant: **Standard** (comma-delimited, dot decimals) or **For Excel**
(semicolon-delimited, decimal comma, UTF-8 byte order mark). A German
Excel opens the second one with the right columns and umlauts. Both
variants re-import.

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

## 6. Backup Reminder

LedgerZero cannot put a backup file somewhere safe by itself (Android does
not let an app write to your file storage without interaction; the
automatic backups of section 1b stay on the phone). It can remind you to
make one that leaves the phone. Android backup (section 7), when it is on,
also covers a lost phone; the app cannot see whether it is on, so the
reminder says so instead of staying quiet.

### Configure the reminder
1. Navigate to **Settings > Backup & Export**.
2. Tap **Backup reminder**.
3. Select your preferred frequency: Daily, Weekly, Monthly, or Never
   (default: Weekly).

The reminder notification prompts you to open the app and create a backup.
It counts from the last backup that actually left the phone (saved with
"Save to…" or shared), whether automatic backups are on or not.

## 7. Moving to a new phone

* **Android backup** (Android 9 and later; only if backup is on in
  Android's settings, usually Settings > System > Backup, and the phone
  has a screen lock): about once a day, when the phone is idle and on
  Wi-Fi, Android copies the database and the app's settings to your Google
  account, end-to-end encrypted with the phone's screen lock. Without a
  screen lock nothing of LedgerZero is uploaded. Android puts the copy back
  when you set up a new phone from that backup (and when you reinstall the
  app on the same phone). The app cannot check whether it is on; the Backup
  screen explains it. Limits:
  * The copy is as old as the last backup, up to about a day. If you sync
    with a second phone, Wi-Fi sync brings back what that phone has after
    the restore. If you use LedgerZero on one phone only, the changes since
    the last backup are lost.
  * Android backs up at most 25 MB per app and stops without a message
    above that. The Backup screen notes a database above 20 MB; a
    four-year two-person household with about 25,000 transactions
    measured 19.5 MB. Keep saving backup files then.
  * On Android 7 and 8 nothing is backed up (those versions cannot make
    the backup depend on encryption).
* **Android's transfer** (when the new phone is set up from the old one, by
  cable or over Wi-Fi; Android 9 and later): the database and the app's
  settings move along, with or without a screen lock. On Android 7 and 8
  nothing moves; use a backup file or sync there.
* The restored or moved app is a new sync device: at its first start it
  notices that its settings came from a backup or another phone (an install
  marker in Android's no-backup folder, which is never backed up or moved),
  drops the old sync device id, empties the change queue and rebuilds its
  sync state at the next sync like after a restore, so both phones can
  stay in use (`lib/services/backup/transferred_install.dart`).
* What does not move and is set up again on the new phone: the Wi-Fi sync
  pairing (pair again), the automatic-backup password (turn automatic
  backups off and on again), card notification access and its log (turn
  it on again), the automatic backup files (they are in the old phone's
  `Android/data` folder; copy them over if you want them).
* **Without Android backup or the transfer**: make a backup on the old
  phone, save it somewhere the new phone can reach ("Save to…", e.g. a
  cloud app or a USB stick) and restore it there, or set up Wi-Fi sync on
  both phones.
