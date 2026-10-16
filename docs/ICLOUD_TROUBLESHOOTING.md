# iCloud Troubleshooting Guide

This guide helps troubleshoot common issues with iCloud Drive sync in LedgerZero.

## Common Issues

### 1. "iCloud is not available" Error
**Symptoms:**
- Sync settings shows "iCloud is not available. Check that you are signed in to iCloud and that iCloud Drive is on for LedgerZero."
- Unable to connect to iCloud Drive.

**Solutions:**
- **Check Device Settings:** Go to iOS Settings -> [Your Name] -> iCloud -> iCloud Drive and ensure it is turned ON.
- **Check App Permissions:** Go to iOS Settings -> [Your Name] -> iCloud -> Apps using iCloud -> Show All -> LedgerZero and ensure it is turned ON.
- **Sign In:** Ensure you are signed in with your Apple ID on the device.

### 2. Connecting to iCloud fails
**Symptoms:**
- An error appears after tapping **Connect to iCloud** (the app could not access its iCloud container).

**Solutions:**
- **Network Connection:** Ensure you have an active internet connection. iCloud requires network access to verify the container initially.
- **Simulator Issues:** If running on a Simulator, sign in to iCloud in the Simulator settings. Note that iCloud sync is often unreliable on Simulators.

### 3. Sync is stuck or slow
**Symptoms:**
- Status stays "Syncing…" for a long time.
- Changes made on one device don't appear on another.

**Solutions:**
- **Trigger Manual Sync:** Go to Settings -> Sync Settings and tap "Sync Now".
- **Check Battery/Data Mode:** Low Power Mode or Low Data Mode can delay iCloud's own uploads and downloads. (LedgerZero itself syncs only while the app is open and unlocked.)
- **Restart App:** Force close and reopen the app to restart the sync service.
- **Check Apple System Status:** Visit [Apple System Status](https://www.apple.com/support/systemstatus/) to check for iCloud Drive outages.

### 4. "Storage Full" Error
**Symptoms:**
- Uploads fail consistently.
- Device shows system notification about iCloud storage.

**Solutions:**
- **Free Up Space:** Delete unnecessary files from iCloud Drive or upgrade your storage plan.
- **Check LedgerZero Usage:** LedgerZero's encrypted change files are small (KB). Each device periodically writes a snapshot and deletes its own change files covered by it, so the folder does not grow without bound.

### 5. Changes not appearing on another iPhone/iPad
**Symptoms:**
- One device has data the other one doesn't.

**Solutions:**
- **Same Apple ID:** Ensure both devices are signed in with the *exact same* Apple ID.
- **iCloud Drive Enabled:** Verify iCloud Drive is enabled on *both* devices.
- **Wait for Sync:** iCloud propagation can sometimes take a few minutes. A device applies another device's files strictly in order, so it waits until a missing file has arrived.
- **Sync settings notices:** "change files could not be applied" (Retry / Share diagnostics / Skip file) or "Another device uses a newer version of LedgerZero. Update the app to sync its changes."

## Advanced Debugging

### Resetting Sync
The sync folder is the app's iCloud container; it is not shown in the Files
app. To start over:
1. Disconnect iCloud in LedgerZero Sync settings on every device.
2. Reconnect on one device: if the old folder is still there, you are asked
   for its sync passphrase; restoring a backup on a device also rebuilds its
   sync state automatically.

### Viewing Logs
- The diagnostic log (Settings > Security Settings > Diagnostic log) shows recent log entries; sync messages start with `Sync` or `iCloud`.
