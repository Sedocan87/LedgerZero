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
   - If you uploaded backups, the `LedgerZero/Backups` folder on Google Drive contains encrypted backups (`.lzbk`).
   - Uninstall and reinstall the app, then complete onboarding.
   - Go to **Settings > Backup & Export**, tap **Restore from file**, pick the `.lzbk` file and enter its backup password.
   - A restore that was interrupted (the app was killed while it replaced
     the database) is finished automatically at the next start.

2. **Manual Extraction (Advanced)**:
   - The database is `db.sqlite` in the app's documents directory (`/data/data/com.ledgerzero.app/app_flutter/`).
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
   - *Skip file* continues with that device's next file. The changes in the
     skipped file arrive later with that device's next snapshot: the app
     asks the other device for one, and it writes one the next time it
     syncs. A file that cannot be read at all is skipped automatically
     after the last retry, the same way.
5. **"N files from an old sync folder"**: the folder still contains files
   written before it was set up again (they cannot be read with the
   current passphrase). They are ignored; tap *Remove* to delete them from
   the folder or *Ignore* to stop listing them.
6. **"Update the app to sync"**: another device runs a newer LedgerZero
   version. Update this device; the waiting files are then applied.
7. **Sync conflicts**: edits on this device that lost against newer edits
   elsewhere are listed under *Sync conflicts* (Keep mine / Dismiss). The
   Home screen's sync card also shows how many conflicts and files need
   attention.
8. **Clocks**: Wi-Fi sync refuses a phone whose clock differs by more than
   two minutes ("the other phone's clock differs by N minutes"); set both
   phones to automatic date and time. A notice in Sync settings tells you
   when another device's change files carry times from the future: its
   edits win every conflict until its clock is fixed.
9. **Rebuild this device's sync state**: restoring a backup (Settings >
   Backup & Export) rebuilds the sync state automatically from the latest
   snapshot and the change files in the cloud. A fresh install that joins
   the folder does the same.
10. **Resetting the sync folder** (new passphrase, or starting over): do it
    on one device and delete the **whole** folder content first — not only
    the manifest. Old change files left behind cannot be read with the new
    key; they show up as "files from an old sync folder" and can be
    removed from Sync settings. Then set up sync on one device and join on
    the others. Wi-Fi sync: tap *Turn off* on both phones and pair again.

## 3. App Lock and Database Key

There is no master password. The database key lives in the phone's
KeyStore; the app lock uses the phone's own screen lock (fingerprint,
face, PIN, pattern or password).

### Symptoms
- The app lock does not accept you: use the phone's PIN, pattern or
  password, the same way the lock screen does.
- "The key data of this app is missing".

### Recovery Steps
1. **"The key data of this app is missing"** (the KeyStore entry holding the
   database key was removed, e.g. after a security reset of the phone): the
   data on this phone cannot be opened any more. The lock screen offers
   **Reset app**; after typing the confirmation word it performs the
   factory reset (database with its WAL/SHM files and any restore leftover,
   key entries, preferences, exported files, local sync files and the
   Wi-Fi pairing) and returns to onboarding, where you can set up the app
   and restore a backup.
2. **Backup**: restore it in Settings > Backup & Export with its backup
   password (chosen when the backup was made). If automatic backups were
   on, the reset keeps them: **Restore an automatic backup** lists them,
   newest first, and they open with the password chosen when the feature
   was turned on. Without a backup the data on this phone is gone; with
   sync, the shared data comes back from the sync folder after joining it
   again (personal transactions do not — they exist only in this phone's
   backups).
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
