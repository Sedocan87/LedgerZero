# Troubleshooting Guide

This guide helps you resolve common issues with LedgerZero.

## Common Error Messages

### "Database disk image is malformed"
**Cause:** The database file has been corrupted, likely due to a sudden power loss or hardware issue.
**Solution:**
1. Restore from a cloud backup (if enabled).
2. If you have no backup, you may need to reinstall the app (warning: data loss).

### "Sync failed: Storage quota exceeded"
**Cause:** Your Google Drive or iCloud storage is full.
**Solution:**
1. Free up space on your cloud provider.
2. Or empty the Trash in your cloud provider.

### "Sync failed: User not signed in"
**Cause:** The authentication token has expired or is invalid.
**Solution:**
1. Go to Settings > Sync.
2. Sign out and Sign in again.

### "Network error" / "No internet connection"
**Cause:** The device cannot reach the internet.
**Solution:**
1. Check your Wi-Fi or cellular connection.
2. If on Cellular, ensure LedgerZero has permission to use cellular data.
3. Toggle Airplane mode on/off.

### "Decryption failed" / "Incorrect Password"
**Cause:** The password provided does not match the one used to encrypt the database.
**Solution:**
1. Double-check caps lock and spelling.
2. Use your Recovery Key if you have it.
3. If lost, you must reset the app (data will be lost unless you have a backup with a known password).

## Logs & Diagnostics

### How to send logs
If you need to report a bug, you can attach logs:
1. Go to **Settings > About**.
2. Tap **Export Logs** (if available) or navigate to `Documents/logs` on your device.
3. Send the `.jsonl` files.

### Crash Reports
Crash reports are stored in `Documents/logs/crashes`. These contain detailed technical information about why the app closed unexpectedly.
