# LedgerZero Security Architecture

LedgerZero is local-first: your data lives in an encrypted database on your
device. This document states what is protected, how, and what is not. The
key design is described in detail in [ENCRYPTION.md](ENCRYPTION.md).

## 1. Data at rest

| Data | Protection |
| --- | --- |
| Database (`db.sqlite` in the app documents directory) | SQLCipher 4 (AES-256), keyed with a random 256-bit data key (DEK) passed as a raw key. The connection refuses to open without the right key or without SQLCipher. |
| Data key | Never stored in plaintext. Stored only wrapped with AES-256-GCM by (1) an Argon2id key from the master password, (2) a key from a 160-bit recovery key, (3) optionally a Keystore key that needs a fresh biometric authentication. |
| Key vault | flutter_secure_storage 10: Android KeyStore-protected storage. |
| Backups (`.lzbk`) | Always encrypted (AES-256-GCM, Argon2id from a backup password, streamed in authenticated chunks). See [BACKUP_FORMAT.md](BACKUP_FORMAT.md). |
| Exports (CSV, JSON, PDF, PNG, diagnostic log) | Plaintext by design. Written to the app's cache directory (not backed up), deleted once the share sheet completes (on Android 60 s later, because the receiving app may still be reading), and swept at start-up/resume if older than one hour. |
| Captured card notifications (Android, only when enabled) | Title and text of notifications from the bank/card apps the user chose, queued until the next unlock: AES-256-GCM with an Android KeyStore key that needs no user authentication (the listener writes while the app is locked), max. 200 entries / 90 days. See [CARD_NOTIFICATIONS.md](CARD_NOTIFICATIONS.md). |
| Diagnostic logs / crash reports | Off by default. When enabled, stored in the app cache directory, with SQL parameters, e-mail addresses, payloads and numbers removed. Shared only by the user, after a preview of the exact text. |

Android: `android:allowBackup="false"`, so Google's auto backup never copies
the database or key storage.

## 2. Authentication and session

* **Master password**: at least 10 characters, not a common password, with a
  local strength meter. A wrong password is detected by the AES-GCM tag of
  the wrapped key; there is no password hash stored.
* **Recovery key**: shown at onboarding with an explicit "I saved it" step;
  can be shown again or replaced in Settings > Security Settings after
  re-entering the password. Unlocking with it requires setting a new password. It is
  never put on the clipboard.
* **Biometrics**: Android BiometricPrompt with a Keystore `CryptoObject`
  (BIOMETRIC_STRONG, per-use authentication, invalidated when enrolment
  changes). A "yes/no" biometric check alone never releases the key.
* **Session**: the data key lives only in `sessionProvider` while unlocked.
  Locking closes the database connection, zeroes the key bytes and emits
  `AppLockState.locked` (`appLockStateProvider`).
* **Auto-lock**: Immediate (default) locks as soon as the app is inactive or
  in the background; timed modes lock after 1–30 minutes in the background
  (monotonic clock and wall clock, the larger wins).
* **Password change** re-wraps the data key in one write; the database is
  not re-keyed and the recovery key keeps working.

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

## 5. Cloud synchronisation

* Bring-your-own storage (Google Drive, `drive.file` scope).
* **End-to-end encrypted:** every change file and snapshot is encrypted with
  AES-256-GCM under a key derived from the user's sync passphrase (Argon2id,
  same parameters as the master password, then HKDF bound to the folder's
  sync id). The cloud folder holds only ciphertext plus a manifest with the
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
* Sync pauses while the app is locked (the controller follows
  `appLockStateProvider` and cancels a running sync).

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
  headers (schema version, change counts, newest change time).
* A weak sync passphrase: the KDF slows guessing, but anyone with folder
  access can try passphrases offline against the manifest.
* Data on screen while the app is unlocked, and process memory of an
  unlocked app on a rooted/jailbroken device.
* Strings and native copies of the key (SQLCipher holds its own copy while
  the database is open) cannot be wiped from Dart.
* Plaintext exports once the user has shared them with another app.
* Queued card notifications on a rooted device: their KeyStore key is usable
  by the app without authentication, so code running as the app can read
  them.
* Losing both the master password and the recovery key makes the data
  permanently unreadable; there is no back door.

## 8. Privacy

* No analytics or tracking SDKs; nothing is sent anywhere except to the cloud
  storage the user configured.
* The app works fully offline.
