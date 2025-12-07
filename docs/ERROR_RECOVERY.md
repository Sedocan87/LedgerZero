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
   - If Cloud Sync is enabled, the `backups/` folder in your cloud provider (Google Drive or iCloud) contains periodic backups of the database.
   - Uninstall the app.
   - Reinstall the app.
   - During onboarding, choose "Restore from Backup".

2. **Manual Extraction (Advanced)**:
   - On Android, the database is located in `/data/data/com.ledgerzero.app/databases/db.sqlite`.
   - On iOS, it is in the App Sandbox Documents/Library.
   - You can try to copy this file out using platform tools and inspect it with an SQLite browser (providing the encryption key).

## 2. Synchronization Issues

### Symptoms
- Changes on one device do not appear on another.
- "Sync Failed" notifications.

### Recovery Steps
1. **Check Connectivity**: Ensure both devices have internet access.
2. **Verify Cloud Provider**:
   - Go to Settings > Sync.
   - Ensure you are signed in to the correct account.
   - Check if your Cloud Storage (Google Drive/iCloud) is full.
3. **Force Sync**:
   - Pull-to-refresh on the Home Screen.
   - Check the Sync Debug log (Settings > Sync > Debug).
4. **Reset Sync State (Last Resort)**:
   - If a device is stuck processing a specific Delta file:
     - Clear the local delta queue in Sync Debug settings (if available in future builds).
     - Or uninstall/reinstall to pull a fresh state from the cloud (deltas will be re-downloaded).

## 3. Password/Encryption Key Loss

### Symptoms
- Cannot unlock the app.

### Recovery Steps
1. **Recovery Key**:
   - Use the "Recovery Key" generated during initial setup. This bypasses the password.
2. **No Recovery Key?**:
   - **Data is unrecoverable.**
   - You must uninstall and reinstall the app.
   - If you have a backup *and* know the password for that backup (it uses the same key as when the backup was made), you can restore.

## 4. Application Crashes

### Symptoms
- App closes unexpectedly.

### Recovery Steps
1. **Check Crash Reports**:
   - LedgerZero saves crash reports to the device storage.
   - Navigate to the app's document folder (if accessible via file manager) or check `Logs` in Settings (if the app opens).
2. **Update App**: Ensure you are on the latest version.
3. **Clear Cache/Data**:
   - **Warning**: Clearing Data deletes the local database. Only do this if you have a backup or cloud sync.
