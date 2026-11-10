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
2. Tap **Disconnect** and confirm, then connect again and enter your sync
   passphrase. Changes made in between are kept and sent after you
   reconnect.

### "No connection to the cloud storage"
**Cause:** The device cannot reach the internet. Sync tries again when you are online.
**Solution:**
1. Check your Wi-Fi or cellular connection.
2. If on Cellular, ensure LedgerZero has permission to use cellular data.
3. Toggle Airplane mode on/off.

## Start-up and app lock

LedgerZero keeps the budget in its private storage on the phone; there is
no master password and no key to lose. The optional app lock uses your
fingerprint, face or screen lock (see [SECURITY.md](SECURITY.md)).

### The app lock does not appear or cannot be turned on
* The app lock needs a screen lock (PIN, pattern or password) on the phone.
  Set one up in the Android settings, then turn the lock on in
  **Settings > Security**. Turning it on asks for your fingerprint, face or
  screen lock once.
* "This phone has no screen lock any more, so the app lock was turned off":
  the screen lock was removed in the Android settings. Set one up again and
  turn the app lock back on.

### "Unlocking did not work: ..."
The system prompt failed for a reason other than a removed screen lock
(sensor busy, too many attempts, hardware unavailable). The app stays
locked; the system's message is shown. Wait a moment and tap **Unlock**
again, or use the PIN/pattern/password option of the prompt.

### "LedgerZero could not open its database file just now"
The database file could not be read (storage busy or full). Your data is
not affected. Tap **Retry** or restart the phone; **Reset app** is offered
next to **Retry** only after three failed tries.

### "LedgerZero cannot read the data on this phone: the database file is damaged"
The file is not a readable database any more (see "Database disk image is
malformed" above). The screen offers **Reset app** next to **Retry**. It
asks you to type a confirmation word (`RESET`; German `ZURÜCKSETZEN`) and
then runs the same factory reset as **Settings > Factory Reset**: it
deletes the database with its `-wal`/`-shm` files, exported files, local
crash reports and all preferences, and opens onboarding. Automatic backups
on the phone are kept. Set the app up again, then restore a backup in
**Settings > Backup & Export** or sync again from your other phone.

### "The data on this phone was saved by an early test version"
Development builds before schema v20 are not upgraded any more. Reset the
app as above and set it up again.

## Backups and moving to a new phone

* Backups always need the backup password chosen when the backup was made.
* "This backup was made by a newer version": update the app first.
* "This backup was made by an early test version": backups of development
  builds before schema v20 cannot be restored.
* "The backup password is no longer stored on this phone": the phone's key
  store lost it, or the app moved to a new phone (the stored password does
  not move along). Turn **Automatic backups** off and on again and enter the
  password.
* Moving to a new phone: Android's transfer when setting up the new phone
  (cable or Wi-Fi, Android 9 and later) takes the budget and the settings
  along; Google's cloud backup never does. On the new phone pair Wi-Fi sync
  again, sign in to Google Drive again, turn card notifications on again
  and re-enter the automatic-backup password. Otherwise use a backup file
  or sync.
* Entering a backup password or sync passphrase takes up to about a second
  on a mid-range phone: that is the deliberate cost of Argon2id key
  derivation, which makes guessing them expensive.

## Logs & Diagnostics

Crash reports are **off by default**. To help with a bug:
1. Go to **Settings > Security Settings > Privacy** and turn on **Save crash
   reports**. Errors are then recorded on this device only, with amounts,
   e-mail addresses and database values removed.
2. Reproduce the problem.
3. Open **Diagnostic log** in the same section. It shows exactly the text that
   will be shared; tap **Share diagnostic log** to send it, or **Delete
   diagnostic data**.

The diagnostic log always starts with the app version and build, the
Android version, the device model, the system locale and the database
schema version, also while crash reports are off and nothing has been
recorded. It contains no device name and no account.

The logs are kept in the app's cache directory (not included in device
backups) and are never sent automatically.
