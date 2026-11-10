# LedgerZero Security Architecture

LedgerZero is local-first: your budget lives on your phone, in the app's
private storage. There is no account, no LedgerZero server and no tracking.
Everything that leaves the phone (backups, sync files) is encrypted with a
password or passphrase only the user knows. This document states what is
protected, how, and what is not. The cryptography of backups and sync is
described in [ENCRYPTION.md](ENCRYPTION.md).

## 1. Data at rest

| Data | Protection |
| --- | --- |
| Database (`db.sqlite` in the app documents directory, `app_flutter/` on Android) | A plain SQLite file in the app's private storage. Android's app sandbox keeps other apps out; file-based encryption (bound to the screen lock) protects it while the phone is locked after a restart. The app does not encrypt it itself (see section 7). |
| Backups (`.lzbk`) | Always encrypted (AES-256-GCM, Argon2id from a backup password, streamed in authenticated chunks). See [BACKUP_FORMAT.md](BACKUP_FORMAT.md). |
| Sync files (Google Drive or Wi-Fi) | Always encrypted (AES-256-GCM under a key from the sync passphrase). See section 5. |
| Automatic-backup password, Wi-Fi pairing secret | flutter_secure_storage 11 (AES-GCM under an Android KeyStore key). If the KeyStore loses that key, the entries are deleted and read as missing: the user enters the backup password again or pairs again (`resetOnError`, `lib/services/security/secure_store.dart`). Nothing else depends on them. |
| Exports (CSV, JSON, PDF, PNG, diagnostic log) | Plaintext by design. Written to the app's cache directory (not backed up), deleted once the share sheet completes (on Android 60 s later, because the receiving app may still be reading), and swept at start-up/resume if older than one hour. |
| Captured card notifications (Android, only when enabled) | Title and text of notifications from the bank/card apps the user chose, kept as a log until the app next runs and for 30 days after they were handled: AES-256-GCM with an Android KeyStore key that needs no user authentication, max. 500 entries (pending ones for 90 days). If the KeyStore key is lost, the log is started over and the user is told the date. See [CARD_NOTIFICATIONS.md](CARD_NOTIFICATIONS.md). |
| Diagnostic logs / crash reports | Warnings and errors are always written to the app cache directory (so a release build can explain afterwards why something did not happen, e.g. a card notification that could not be booked); info/debug lines only with logging enabled; crash reports only when the user turns them on. All of it with SQL parameters, e-mail addresses, payloads and numbers removed. Never uploaded; shared only by the user, after a preview of the exact text. |

### Android backup and moving to a new phone

`android:allowBackup="true"` with rules that keep the cloud out
(`android/app/src/main/res/xml/data_extraction_rules.xml`,
`res/xml/backup_rules.xml`, `res/xml-v28/backup_rules.xml`):

| Android version | Cloud backup (Google Drive) | Device-to-device transfer (new phone set up from the old one) |
| --- | --- | --- |
| 12 and later (`dataExtractionRules`) | nothing | the database (`app_flutter/db.sqlite` and its `-wal`) and the preferences (`FlutterSharedPreferences.xml`) |
| 9 to 11 (`fullBackupContent`, `res/xml-v28`) | nothing: every include needs `requireFlags="deviceToDeviceTransfer"` | the same files |
| 7.0 to 8.1 (`fullBackupContent`, `res/xml`) | nothing | nothing: these versions ignore `requireFlags`, so a cloud backup could not be told apart; the budget moves through a backup file or sync |

`allowBackup` has to be true for the transfer (on Android 12 and later
`false` turns off the cloud backup, and on some devices the transfer too).
The rules include only the files listed, so everything else stays behind:
the secure storage (its KeyStore key cannot move), the card capture store
(KeyStore-encrypted; it starts empty), exports, the sync folder and the
automatic backups (external storage).

A moved install would keep the old phone's sync device id. Every install
therefore writes a random install id into its preferences and into a
marker in `Context.getNoBackupFilesDir()`, which Android never backs up or
moves (`lib/services/backup/transferred_install.dart`, checked in
`bootstrap()` before anything reads the device id). Preferences with an id
that the marker does not have came from another phone: that install drops
the device id (preferences and `sync_kv`), empties the change queue, sets
the sync re-bootstrap flag (like a restore, section 4) and forgets the old
phone's Wi-Fi peers. The rest of what moved is handled where it is used:
the app lock setting (turned off by the lock screen if the new phone has no
screen lock), automatic backups (the Backup screen asks for the password
again), Wi-Fi sync (asks to pair again), Google Drive (sign in again), card
capture (notification access is granted again).

## 2. App lock and session

* **App lock** (Settings > Security, offered at onboarding): the system
  prompt for a fingerprint/face or the device PIN, pattern or password
  (BiometricPrompt, BIOMETRIC_STRONG or DEVICE_CREDENTIAL; below API 30
  BIOMETRIC_WEAK or DEVICE_CREDENTIAL). It gates the UI; it does not
  release a key. Turning it on needs a screen lock and one successful
  prompt; if the screen lock is later removed (`KeyguardManager.
  isDeviceSecure` false), the app turns the lock off instead of locking the
  user out. Every other failure of the prompt (sensor unavailable, lockout,
  missing channel) keeps the app locked and shows the system's reason with
  "Unlock" to try again.
* **Session**: the start-up screen checks the database file and opens it
  (`sessionProvider`), then shows the app lock. The session stays open while
  the lock is showing (sync and card capture keep running) and is closed
  only for a factory reset.
* **Auto-lock** (only with the app lock on): after 1 minute in the
  background by default; "Immediate" locks as soon as the app is hidden or
  paused (not on `inactive`: the notification shade or a system dialog
  over the app does not lock); timed modes lock after 1–30 minutes in the
  background (monotonic clock and wall clock, the larger wins). OS screens
  the app opens itself (file picker, share sheet, the lock prompt) do not
  lock, for at most 2 minutes each.
* **Start-up failures** (`checkDatabaseFile`,
  `lib/data/database/connection_native.dart`): a database file that cannot
  be read at all (I/O) is retried; the destructive "Reset app" is offered
  next to "Retry" after three failed tries, or at once when the file is not
  a database (damaged) or was written by an early test version (schema
  below v20, which is not upgraded any more). Onboarding never deletes a
  database with accounts in it.

## 3. Screen privacy

* Android: `FLAG_SECURE` on the activity (no screenshots/recording, blank
  app-switcher thumbnail) and `setRecentsScreenshotEnabled(false)` on API 33+.
* Flutter: `PrivacyShield` covers the UI whenever the lifecycle state is not
  `resumed`.
* Reminder notifications contain no amounts unless the user turns that on;
  Android notifications use `VISIBILITY_PRIVATE`.

## 4. Backup and restore

* Backups are snapshots written with `VACUUM INTO` into a temporary file,
  encrypted, and the temporary file deleted.
* Restore decrypts into the temporary directory, validates the database
  (integrity, required tables, schema version between v20 and the current
  one; older backups come only from development builds and are refused),
  copies it next to the live file, checks the copy, swaps it in atomically
  (one previous copy kept until the new database passes a check, rolled back
  otherwise; an interrupted swap is finished at the next start) and reopens
  it without restarting the app.
* After a restore the local sync queue is cleared and the
  `sync_rebootstrap_required` flag is set: the next sync rebuilds the
  device's sync state from the latest snapshot and the change files (newer
  changes from other devices win), then shares the restored rows again.

## 5. Synchronisation

* Bring-your-own storage (Google Drive, `drive.file` scope), or phone to
  phone on the local Wi-Fi without any cloud (see below).
* **End-to-end encrypted:** every change file and snapshot is encrypted with
  AES-256-GCM under a key derived from the user's sync passphrase (Argon2id,
  m = 46 MiB, t = 2, then HKDF bound to the folder's sync id). The cloud
  folder holds only ciphertext plus a manifest with the KDF salt/parameters
  and a key-check value. File headers (device id, sequence, schema version,
  counts, timestamps) are readable but authenticated. Without the passphrase
  nobody with folder access can read rows or inject them; tampered,
  truncated or renamed files fail authentication and are quarantined. See
  [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md).
* The derived sync key is stored inside the database (`sync_kv`), and
  therefore in backups (which are encrypted). The passphrase is never
  stored.
* Remote file names are validated against a strict pattern before use and
  never become local paths.
* Sync runs whenever the database is open, also behind the app lock (the
  controller follows `appLockStateProvider`, which is the database session,
  and cancels a running sync when it closes).
* **Wi-Fi sync**: the paired phones authenticate every request and
  response with HMAC-SHA256 under a random 256-bit pair key (with a 2-minute
  time window and replay protection); discovery beacons are tagged with it
  too. Pair key and sync passphrase travel only in the pairing QR code
  shown on one phone and scanned on the other, and are stored in the
  KeyStore-protected secure storage. The files exchanged are the same
  AES-GCM encrypted change files as on Drive. The server listens only while
  the app is open.

## 6. Application security

* SQL uses bound parameters (Drift). Interpolated statements contain only
  values the app generates (`PRAGMA user_version = <int>`, table names from
  a fixed list).
* CSV exports neutralise cells starting with `=`, `+`, `-`, `@`, tab or CR
  (prefix `'`) to prevent spreadsheet formula injection; amounts and dates
  produced by the app are written as plain values.
* Logging: no e-mail addresses, sync change payloads or authentication state are
  logged; debug output of the router is removed.
* Randomness: `Random.secure()`.
* The SQLite binaries are verified by SHA-256 hashes pinned in the `sqlite3`
  package (see [ENCRYPTION.md](ENCRYPTION.md#supply-chain)).
* Android release builds use R8 shrinking/obfuscation.

## 7. What is not protected

* **The database file is not encrypted by the app.** Anyone or anything that
  can read the app's private storage can read the budget: code running as
  the app or as root on a rooted or exploited phone, a forensic tool on an
  unlocked phone, `adb backup` / `run-as` on a debug build. The app lock
  does not stop that; it gates the UI only. This was decided in exchange
  for a budget that can move to a new phone (device-to-device transfer) and
  for no key to lose: Android's sandbox and file-based encryption cover the
  realistic cases (another app, a stolen locked phone).
* Sync metadata visible in the cloud folder: file names (random device ids
  and sequence numbers), file sizes and times, and the authenticated file
  headers (schema version, change counts, newest change time). On the local
  network, Wi-Fi sync traffic is plain HTTP: others on the network can see
  that two phones exchange files, their names and sizes (not their content)
  and the discovery beacons (device id and name).
* Anyone who sees the pairing QR code (or its text) can join the shared
  budget; the app warns when showing it.
* A weak sync passphrase or backup password: the KDF slows guessing, but
  anyone with the folder or the backup file can try passwords offline.
* Data on screen while the app is unlocked.
* Strings in memory cannot be wiped from Dart.
* Plaintext exports once the user has shared them with another app.
* **Losing the phone (or a factory reset of the phone) loses the data**
  unless there is a backup file somewhere else or a second phone that
  syncs; onboarding and the Backup screen say so. Automatic backups
  (Settings > Backup & Export) live on the phone and go with it; they cover
  a database that cannot be opened any more and are kept by the reset that
  such a failure needs ([BACKUP_AND_EXPORT.md](BACKUP_AND_EXPORT.md)).

## 8. Privacy

* No analytics or tracking SDKs; nothing is sent anywhere except to the cloud
  storage the user configured.
* No cloud backup by Android (section 1).
* The app works fully offline.
