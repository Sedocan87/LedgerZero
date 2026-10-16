# Cloud Provider Comparison: iCloud Drive vs Google Drive

LedgerZero has no server. Sync and cloud backups use a folder in your own
cloud storage. Choose the provider in **Settings > Sync Settings**.

## Summary

| | iCloud Drive | Google Drive |
|---|---|---|
| Available on | iOS only | iOS and Android |
| Sign-in | Apple ID signed in on the device, iCloud Drive enabled | Google sign-in in the app (OAuth) |
| Location | App's iCloud container `iCloud.com.ledgerzero.app` (sync files at the root, backups in `Backups/`) | `LedgerZero/Sync` and `LedgerZero/Backups` in your Drive |
| App access | Only the app's own container | `drive.file` scope: only files the app created |
| File encryption | Same for both (see below) | Same for both |
| When it syncs | Same schedule for both (see below) | Same schedule for both |

All devices that sync with each other must use the **same provider and the
same account**. An iPhone and an Android phone can only sync through Google
Drive.

## What is the same for both

- **Encryption**: every change file and snapshot is AES-256-GCM encrypted
  with a key derived from your **sync passphrase** (Argon2id + HKDF). The
  manifest in the cloud folder holds the salt, KDF parameters and a
  key-check value, not the key. Apple or Google can store the files but not
  read them. Backups are always encrypted with a backup password. Details:
  [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md),
  [ENCRYPTION.md](ENCRYPTION.md), [BACKUP_FORMAT.md](BACKUP_FORMAT.md).
- **Sync behaviour**: one encrypted change file per sync run; conflicts are
  resolved per row by the newest `updated_at` (UTC), with the device id as
  tiebreaker. Files that cannot be applied are quarantined and retried. A
  new device starts from an encrypted snapshot.
- **Timing**: the app syncs when it is unlocked, on resume, shortly after
  local changes, on the interval chosen under **Sync Frequency**, and when
  the network returns; with **Manual** only on **Sync Now**. Neither provider pushes changes to the app; a device
  sees remote changes at its next sync. **Sync only on Wi-Fi** applies to
  automatic syncs on both.

## Differences in practice

- **Setup**: iCloud needs no sign-in in the app, but iCloud Drive must be on
  and allowed for LedgerZero (iOS Settings). Google Drive needs a sign-in
  and consent to the `drive.file` permission. See
  [ICLOUD_SETUP.md](ICLOUD_SETUP.md) and
  [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md).
- **Transfers**: iCloud uploads and downloads are handled by iOS; a slow
  upload may finish in the background after the sync run. Google Drive
  transfers happen during the sync run and are retried on transient errors.
- **Storage quota**: the files count towards your iCloud or Google storage.

## Recommendation

- Only iPhones/iPads: either works; iCloud Drive needs no extra account.
- Any Android device involved: Google Drive.

Troubleshooting: [ICLOUD_TROUBLESHOOTING.md](ICLOUD_TROUBLESHOOTING.md),
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).
