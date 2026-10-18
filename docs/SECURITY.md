# LedgerZero Security Architecture

LedgerZero is local-first: your data lives in an encrypted database on your
device. This document states what is protected, how, and what is not. The
key design is described in detail in [ENCRYPTION.md](ENCRYPTION.md).

## 1. Data at rest

| Data | Protection |
| --- | --- |
| Database (`db.sqlite` in the app documents directory) | SQLCipher 4 (AES-256), keyed with a random 256-bit data key (DEK) passed as a raw key. The connection refuses to open without the right key or without SQLCipher. |
| Data key | Stored by flutter_secure_storage 10 (AES-GCM under an Android KeyStore key that needs no user authentication), so the database opens whenever the app runs, also behind the app lock. There is no master password. |
| Backups (`.lzbk`) | Always encrypted (AES-256-GCM, Argon2id from a backup password, streamed in authenticated chunks). See [BACKUP_FORMAT.md](BACKUP_FORMAT.md). |
| Exports (CSV, JSON, PDF, PNG, diagnostic log) | Plaintext by design. Written to the app's cache directory (not backed up), deleted once the share sheet completes (on Android 60 s later, because the receiving app may still be reading), and swept at start-up/resume if older than one hour. |
| Captured card notifications (Android, only when enabled) | Title and text of notifications from the bank/card apps the user chose, kept as a log until the app next runs and for 30 days after they were handled: AES-256-GCM with an Android KeyStore key that needs no user authentication, max. 500 entries (pending ones for 90 days). If the KeyStore key is lost, the log is started over and the user is told the date. See [CARD_NOTIFICATIONS.md](CARD_NOTIFICATIONS.md). |
| Diagnostic logs / crash reports | Warnings and errors are always written to the app cache directory (so a release build can explain afterwards why something did not happen, e.g. a card notification that could not be booked); info/debug lines only with logging enabled; crash reports only when the user turns them on. All of it with SQL parameters, e-mail addresses, payloads and numbers removed. Never uploaded; shared only by the user, after a preview of the exact text. |

Android: `android:allowBackup="false"`, so Google's auto backup never copies
the database or key storage. Android's file-based encryption protects all of
it while the phone has not been unlocked since a restart.

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
* **Session**: the start-up screen opens the database with the device key
  (`sessionProvider`), then shows the app lock. The session stays open while
  the lock is showing (sync and card capture keep running) and is closed
  only for a factory reset; closing zeroes the key bytes.
* **Auto-lock** (only with the app lock on): after 1 minute in the
  background by default; "Immediate" locks as soon as the app is hidden or
  paused (not on `inactive`: the notification shade or a system dialog
  over the app does not lock); timed modes lock after 1–30 minutes in the
  background (monotonic clock and wall clock, the larger wins). OS screens
  the app opens itself (file picker, share sheet, the lock prompt) do not
  lock, for at most 2 minutes each.
* **Start-up failures**: a key store or database file that fails to open
  is retried; the destructive "Reset app" is offered only when the key is
  missing or does not match the database, or after three failed retries
  (or a key store error that is known to be permanent: the KeyStore
  wrapping key was wiped). Onboarding never deletes a database that the
  stored device key opens.
* **Older installs** with a master password unlock once with the password,
  recovery key or biometrics; the data key then moves to the device key
  store and the vault is deleted (see [ENCRYPTION.md](ENCRYPTION.md)).

## 3. Screen privacy

* Android: `FLAG_SECURE` on the activity (no screenshots/recording, blank
  app-switcher thumbnail) and `setRecentsScreenshotEnabled(false)` on API 33+.
* Flutter: `PrivacyShield` covers the UI whenever the lifecycle state is not
  `resumed`.
* Reminder notifications contain no amounts unless the user turns that on;
  Android notifications use `VISIBILITY_PRIVATE`.

## 4. Backup and restore

* Backups are snapshots exported with `sqlcipher_export` into a temporary
  plain file, encrypted, and the plain file deleted.
* Restore decrypts into the temporary directory, validates the database
  (integrity, required tables, schema version; older schemas are migrated),
  re-encrypts it with this device's data key, swaps it in atomically
  (one previous copy kept until the new database passes a check, rolled back
  otherwise) and reopens it without restarting the app.
* After a restore the local sync queue is cleared and the
  `sync_rebootstrap_required` flag is set: the next sync rebuilds the
  device's sync state from the latest snapshot and the change files (newer
  changes from other devices win), then shares the restored rows again.

## 5. Synchronisation

* Bring-your-own storage (Google Drive, `drive.file` scope), or phone to
  phone on the local Wi-Fi without any cloud (see below).
* **End-to-end encrypted:** every change file and snapshot is encrypted with
  AES-256-GCM under a key derived from the user's sync passphrase (Argon2id,
  m = 46 MiB, t = 2, then HKDF bound to the folder's sync id). The cloud folder holds only ciphertext plus a manifest with the
  KDF salt/parameters and a key-check value. File headers (device id,
  sequence, schema version, counts, timestamps) are readable but
  authenticated. Without the passphrase nobody with folder access can read
  rows or inject them; tampered, truncated or renamed files fail
  authentication and are quarantined. See
  [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md).
* The derived sync key is stored only inside the encrypted database (and
  therefore in encrypted backups). The passphrase is never stored.
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

* SQL uses bound parameters (Drift). The only interpolated statements are
  `PRAGMA key/rekey` with a hex string generated from bytes.
* CSV exports neutralise cells starting with `=`, `+`, `-`, `@`, tab or CR
  (prefix `'`) to prevent spreadsheet formula injection; amounts and dates
  produced by the app are written as plain values.
* Logging: no e-mail addresses, sync change payloads or authentication state are
  logged; debug output of the router is removed.
* Randomness: `Random.secure()`.
* SQLCipher binaries are verified by SHA-256 hashes pinned in the `sqlite3`
  package (see [ENCRYPTION.md](ENCRYPTION.md#supply-chain)).
* Android release builds use R8 shrinking/obfuscation.

## 7. What is not protected

* Sync metadata visible in the cloud folder: file names (random device ids
  and sequence numbers), file sizes and times, and the authenticated file
  headers (schema version, change counts, newest change time). On the local
  network, Wi-Fi sync traffic is plain HTTP: others on the network can see
  that two phones exchange files, their names and sizes (not their content)
  and the discovery beacons (device id and name).
* Anyone who sees the pairing QR code (or its text) can join the shared
  budget; the app warns when showing it.
* A weak sync passphrase: the KDF slows guessing, but anyone with folder
  access can try passphrases offline against the manifest.
* Data on screen while the app is unlocked.
* Code running as the app on a rooted or exploited phone: the device key
  needs no user authentication, so such code can open the database even
  while the app lock is showing. (The app lock gates the UI only. This was
  accepted in exchange for no master password to lose and for background
  work.)
* Strings and native copies of the key (SQLCipher holds its own copy while
  the database is open) cannot be wiped from Dart.
* Plaintext exports once the user has shared them with another app.
* Losing the phone (or a KeyStore failure, or a factory reset of the phone)
  loses the data unless there is a backup or a second synced phone; the key
  never leaves the device.

## 8. Privacy

* No analytics or tracking SDKs; nothing is sent anywhere except to the cloud
  storage the user configured.
* The app works fully offline.
