# iCloud Troubleshooting Guide

This guide helps troubleshoot common issues with iCloud Drive sync in LedgerZero.

## Common Issues

### 1. "iCloud is disabled" Error
**Symptoms:**
- The app shows an error message saying "iCloud is disabled".
- Unable to connect to iCloud Drive.

**Solutions:**
- **Check Device Settings:** Go to iOS Settings -> [Your Name] -> iCloud -> iCloud Drive and ensure it is turned ON.
- **Check App Permissions:** Go to iOS Settings -> [Your Name] -> iCloud -> Apps using iCloud -> Show All -> LedgerZero and ensure it is turned ON.
- **Sign In:** Ensure you are signed in with your Apple ID on the device.

### 2. "Failed to access iCloud container"
**Symptoms:**
- Error message appears when trying to connect.

**Solutions:**
- **Network Connection:** Ensure you have an active internet connection. iCloud requires network access to verify the container initially.
- **Simulator Issues:** If running on a Simulator, sign in to iCloud in the Simulator settings. Note that iCloud sync is often unreliable on Simulators.

### 3. Sync is stuck or slow
**Symptoms:**
- Status stays "Syncing..." for a long time.
- Changes made on one device don't appear on another.

**Solutions:**
- **Trigger Manual Sync:** Go to Settings -> Sync Settings and tap "Sync Now".
- **Check Battery/Data Mode:** Low Power Mode or Low Data Mode might restrict background sync.
- **Restart App:** Force close and reopen the app to restart the sync service.
- **Check Apple System Status:** Visit [Apple System Status](https://www.apple.com/support/systemstatus/) to check for iCloud Drive outages.

### 4. "Storage Full" Error
**Symptoms:**
- Uploads fail consistently.
- Device shows system notification about iCloud storage.

**Solutions:**
- **Free Up Space:** Delete unnecessary files from iCloud Drive or upgrade your storage plan.
- **Check LedgerZero Usage:** LedgerZero delta files are very small (KB), so it is unlikely to be the sole cause, but a large history can accumulate.

### 5. Changes not appearing on Mac/iOS
**Symptoms:**
- iOS has data, Mac doesn't (or vice versa).

**Solutions:**
- **Same Apple ID:** Ensure both devices are signed in with the *exact same* Apple ID.
- **iCloud Drive Enabled:** Verify iCloud Drive is enabled on *both* devices.
- **Wait for Sync:** iCloud propagation can sometimes take a few minutes.

## Advanced Debugging

### Resetting Sync
If sync is completely broken:
1. Disconnect iCloud in LedgerZero Settings.
2. Go to iOS Files app -> iCloud Drive -> LedgerZero -> Sync.
3. (Optional) Back up these files manually.
4. Reconnect iCloud in LedgerZero.

### Viewing Logs
- Enable Developer Mode in Settings (if available) to view sync logs.
- Look for `[Sync]` tagged logs for specific error codes.
