# Where the data goes: no account, no LedgerZero server

LedgerZero has no server, no account and no sign-in to any cloud service.
The budget lives on the phone. Three things can copy it elsewhere, each
chosen by the user and each end-to-end encrypted:

| | What | Where it goes | Encrypted with | Set up in |
|---|---|---|---|---|
| Wi-Fi sync | change files and snapshots | directly to the paired phone, over the local Wi-Fi | the sync key from the pairing (AES-256-GCM) | Settings > Sync Settings |
| Backup file | the whole database (`.lzbk`) | wherever the user saves or shares it: a folder, a USB stick, a computer, or a cloud app (Drive, Dropbox, ...) chosen in the system file picker | the backup password (Argon2id + AES-256-GCM) | Settings > Backup & Export |
| Android backup | `db.sqlite` (with its `-wal`) and the app's preferences | the user's Google account, through Android's own backup | the phone's screen lock (Android's client-side encryption); nothing is uploaded without it | Android's settings (System > Backup on most phones) |

Earlier builds could also sign in to Google Drive and sync through a
folder there. That is gone (2026-11): the app holds no Google account, no
OAuth client and no Drive permission. A stored "Google Drive" provider of
an older build reads as "None".

## Wi-Fi sync

The two phones of a household sync when both are on the same Wi-Fi with
LedgerZero open; each works on its own in between. There is no relay: two
phones that are never on the same Wi-Fi do not sync. Details:
[SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md#local-wi-fi).

## Backup files in a cloud folder

"Save to…" on the Backup screen opens Android's own "create document"
picker (Storage Access Framework). Installed cloud apps (Google Drive,
Dropbox, OneDrive, Nextcloud, ...) appear there as places to save; the
cloud app does the upload with its own account. LedgerZero only hands over
the encrypted file and never sees the account. See
[BACKUP_AND_EXPORT.md](BACKUP_AND_EXPORT.md).

## Android backup

Android's Auto Backup copies the files named in the backup rules about
once a day (device idle, on Wi-Fi, 24 hours after the last backup) to the
user's Google account, only when the backup is end-to-end encrypted with
the screen lock, and puts them back when the app is reinstalled or a new
phone is set up from that backup. The app cannot read whether it is
switched on. Limits and the exact rules:
[BACKUP_AND_EXPORT.md](BACKUP_AND_EXPORT.md#7-moving-to-a-new-phone),
[SECURITY.md](SECURITY.md#android-backup-and-moving-to-a-new-phone).

Troubleshooting: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
