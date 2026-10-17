# Troubleshooting Guide

This guide helps you resolve common issues with LedgerZero.

## Common Error Messages

### "Database disk image is malformed"
**Cause:** The database file has been corrupted, likely due to a sudden power loss or hardware issue.
**Solution:**
1. Restore a backup (`.lzbk`) in Settings > Backup & Export (backups you
   uploaded are in `LedgerZero/Backups` on Google Drive). See [ERROR_RECOVERY.md](ERROR_RECOVERY.md).
2. If you have no backup, you may need to reinstall the app (warning: data loss).

### "Your cloud storage is full. Free up space to keep syncing."
**Cause:** Your Google Drive storage is full.
**Solution:**
1. Free up space on your cloud provider.
2. Or empty the Trash in your cloud provider.

### "You are not signed in" / "The sign-in has expired"
**Cause:** The authentication token has expired or is invalid.
**Solution:**
1. Go to Settings > Sync Settings.
2. Tap **Disconnect**, then connect again (your sync passphrase may be asked
   for again).

### "No connection to the cloud storage"
**Cause:** The device cannot reach the internet. Sync tries again when you are online.
**Solution:**
1. Check your Wi-Fi or cellular connection.
2. If on Cellular, ensure LedgerZero has permission to use cellular data.
3. Toggle Airplane mode on/off.

### "Incorrect Password"
**Cause:** The password does not unlock your data key.
**Solution:**
1. Double-check caps lock and spelling.
2. Use your recovery key (login screen > **Use recovery key**); you will then
   set a new password.
3. Without password and recovery key the data cannot be decrypted; reinstall
   the app and restore a backup. See [ENCRYPTION_TROUBLESHOOTING.md](ENCRYPTION_TROUBLESHOOTING.md).

## Logs & Diagnostics

Crash reports are **off by default**. To help with a bug:
1. Go to **Settings > Security Settings > Privacy** and turn on **Save crash
   reports**. Errors are then recorded on this device only, with amounts,
   e-mail addresses and database values removed.
2. Reproduce the problem.
3. Open **Diagnostic log** in the same section. It shows exactly the text that
   will be shared; tap **Share diagnostic log** to send it, or **Delete
   diagnostic data**.

The logs are kept in the app's cache directory (not included in device
backups) and are never sent automatically.
