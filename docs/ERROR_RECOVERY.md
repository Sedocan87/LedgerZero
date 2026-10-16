# Error Recovery Guide

This document outlines procedures for recovering from common error scenarios in LedgerZero.

## 1. Database Corruption

Since LedgerZero uses SQLite with SQLCipher, corruption is rare but possible (e.g., unexpected power loss during write).

### Symptoms
- App crashes on launch.
- "Database disk image is malformed" errors in logs.
- Missing data.

### Recovery Steps
1. **Restore from Backup**:
   - If you uploaded backups, the `LedgerZero/Backups` folder (Google Drive) or `Backups/` in the iCloud container contains encrypted backups (`.lzbk`).
   - Uninstall and reinstall the app, then complete onboarding.
   - Go to **Settings > Backup & Export**, tap **Restore from file**, pick the `.lzbk` file and enter its backup password.

2. **Manual Extraction (Advanced)**:
   - The database is `db.sqlite` in the app's documents directory (Android: `/data/data/com.ledgerzero.app/app_flutter/`, iOS: the app sandbox `Documents/`).
   - It is encrypted with SQLCipher under a random data key that is never shown or exported, so a copied file cannot be opened with an SQLite browser. Restore a backup instead.

## 2. Synchronization Issues

### Symptoms
- Changes on one device do not appear on another.
- Sync settings shows an error, "change files could not be applied", or
  "Update the app to sync".

### Recovery Steps
1. **Check connectivity and the account**: Settings > Sync Settings shows the
   provider, the signed-in account, the last sync time and how many local
   changes wait for upload. Check that cloud storage is not full.
2. **Sync now**: tap *Sync Now* (or pull to refresh on the Home screen). With
   frequency *Manual* nothing syncs automatically.
3. **Passphrase**: if Sync settings asks for the sync passphrase, enter the
   one set on your first device. If the cloud folder was deleted or reset,
   set up sync again on one device and join on the others.
4. **Change files that could not be applied**: listed in Sync settings. The
   app retries them automatically with increasing delays; changes from that
   device wait while all other devices keep syncing.
   - *Retry* tries again now (e.g. after an incomplete upload finished).
   - *Share diagnostics* shares file names, attempts and error messages (no
     financial data) for support.
   - *Skip file* continues with that device's next file; the changes in the
     skipped file are not applied on this device (edit them again on the
     device that made them if needed).
5. **"Update the app to sync"**: another device runs a newer LedgerZero
   version. Update this device; the waiting files are then applied.
6. **Sync conflicts**: edits on this device that lost against newer edits
   elsewhere are listed under *Sync conflicts* (Keep mine / Dismiss).
7. **Rebuild this device's sync state**: restoring a backup (Settings >
   Backup & Export) rebuilds the sync state automatically from the latest snapshot and
   the change files in the cloud. A fresh install that joins the folder does
   the same.

## 3. Password/Encryption Key Loss

### Symptoms
- Cannot unlock the app.

### Recovery Steps
1. **Recovery Key**:
   - On the login screen tap **Use recovery key** and enter the recovery key shown during setup. You then set a new master password; the recovery key keeps working.
2. **No Recovery Key?**:
   - **The data on this device is unrecoverable.**
   - Uninstall and reinstall the app.
   - If you have a backup *and* know its backup password (chosen when the backup was made; not necessarily your master password), restore it in Settings > Backup & Export.
3. **"The key data of this app is missing"** (the secure storage holding the
   wrapped data key was emptied, e.g. after moving an iPhone backup to a new
   device): neither the password nor the recovery key can unlock the data.
   The login screen then offers **Reset app**; after typing the
   confirmation word it performs the factory reset (database and its
   WAL/SHM files, key vault entries, preferences, exported files) and
   returns to onboarding, where you can set up the app and restore a backup.
   See [ENCRYPTION_TROUBLESHOOTING.md](ENCRYPTION_TROUBLESHOOTING.md).

## 4. Application Crashes

### Symptoms
- App closes unexpectedly.

### Recovery Steps
1. **Check Crash Reports**:
   - Crash reports are opt-in: turn on **Save crash reports** in Settings > Security Settings (Privacy). They are stored locally in the app's cache directory and never sent anywhere.
   - Review and share them in Settings > Security Settings > **Diagnostic log** (if the app opens).
2. **Update App**: Ensure you are on the latest version.
3. **Clear Cache/Data**:
   - **Warning**: Clearing Data deletes the local database. Only do this if you have a backup or cloud sync.
