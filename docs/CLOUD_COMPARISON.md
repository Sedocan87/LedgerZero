# Cloud Storage: Google Drive

LedgerZero has no server. Sync and cloud backups use a folder in your own
cloud storage. Google Drive is the only provider for now; choose it in
**Settings > Sync Settings**.

## Summary

| | Google Drive |
|---|---|
| Available on | Android |
| Sign-in | Google sign-in in the app (OAuth) |
| Location | `LedgerZero/Sync` and `LedgerZero/Backups` in your Drive |
| App access | `drive.file` scope: only files the app created |

All devices that sync with each other must use the **same Google
account**.

## How it works

- **Encryption**: every change file and snapshot is AES-256-GCM encrypted
  with a key derived from your **sync passphrase** (Argon2id + HKDF). The
  manifest in the cloud folder holds the salt, KDF parameters and a
  key-check value, not the key. Google can store the files but not read
  them. Backups are always encrypted with a backup password. Details:
  [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md),
  [ENCRYPTION.md](ENCRYPTION.md), [BACKUP_FORMAT.md](BACKUP_FORMAT.md).
- **Sync behaviour**: one encrypted change file per sync run; conflicts are
  resolved per row by the newest `updated_at` (UTC), with the device id as
  tiebreaker. Files that cannot be applied are quarantined and retried. A
  new device starts from an encrypted snapshot.
- **Timing**: the app syncs when it is unlocked, on resume, shortly after
  local changes, on the interval chosen under **Sync Frequency**, and when
  the network returns; with **Manual** only on **Sync Now**. Google Drive
  does not push changes to the app; a device sees remote changes at its next
  sync. **Sync only on Wi-Fi** applies to automatic syncs.

## In practice

- **Setup**: Google Drive needs a sign-in and consent to the `drive.file`
  permission. See [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md).
- **Transfers**: happen during the sync run and are retried on transient
  errors.
- **Storage quota**: the files count towards your Google storage.

Troubleshooting: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
