# Encryption Implementation

This document describes exactly what the code does. Source files are named
so you can check every statement.

## Overview

```
 db.sqlite  plain SQLite, app's private storage        app lock: BiometricPrompt
            (Android sandbox + file-based encryption)   (fingerprint/face/device PIN)
     │                                                  gates the UI only
     ├── backup (.lzbk) ── AES-256-GCM, key = Argon2id(backup password)
     └── sync files ────── AES-256-GCM, key = HKDF(Argon2id(sync passphrase), sync id)
```

* The database is **not** encrypted by the app. It is a plain SQLite file
  (`db.sqlite`) in the app documents directory, opened at every start by
  `openConnection` (`lib/data/database/connection_native.dart`). Android's
  app sandbox keeps other apps out, and file-based encryption protects it
  while the phone is locked after a restart. What that leaves open is listed
  in [SECURITY.md](SECURITY.md#7-what-is-not-protected).
* Everything that leaves the phone is end-to-end encrypted with its own
  secret: backups with the backup password ([BACKUP_FORMAT.md](BACKUP_FORMAT.md)),
  sync files with the sync passphrase (QR pairing for Wi-Fi sync;
  [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md)).
* There is no master password, no database key and nothing to lose besides
  those two secrets.

Why no encrypted database: an earlier version encrypted the database with
SQLCipher under a random key kept in the Android KeyStore. That key cannot
leave the phone, so the budget could not move to a new phone with
Android's device-to-device transfer, and a KeyStore failure (some vendors
wipe it on a screen lock change) made the data unreadable. Against what it
added (code running as the app on a rooted or exploited phone could open
the database anyway while the app ran) the owner chose a plain database
that moves to a new phone, with encrypted backups and sync for everything
that leaves it.

## App lock

`lib/services/security/app_lock_authenticator.dart` with native code in
`android/app/src/main/kotlin/com/ledgerzero/app/AppLockChannel.kt`
(`BiometricPrompt`, BIOMETRIC_STRONG or DEVICE_CREDENTIAL; below API 30
BIOMETRIC_WEAK or DEVICE_CREDENTIAL, which is all Android allows there).
It is a UI gate: `AuthState.isAuthenticated`. It is off until the user turns
it on (onboarding offers it when the phone has a screen lock; turning it on
asks for one successful prompt). If the phone's screen lock is removed, the
prompt reports "unavailable" and the app turns the lock off instead of
locking the user out (removing a screen lock needs the old one).

## Start-up, session and locking

* `LockScreen` (`lib/presentation/screens/lock_screen.dart`) runs at every
  start: it checks the database file (`checkDatabaseFile`: finishes an
  interrupted restore, then reads the schema and its version), opens the
  session (`sessionProvider`) and then shows the app lock if it is on.
* `sessionProvider` (`lib/presentation/providers/session_provider.dart`)
  says whether the database is open. `databaseProvider` opens a connection
  when it opens and closes it when it closes or on dispose; only a factory
  reset (and onboarding, before it replaces a database) closes it.
* **`appLockStateProvider`** exposes whether the *database* is open
  (`AppLockState.locked/unlocked`); services that need it (sync) follow it.
  The UI lock is separate (`authProvider`).
* Auto-lock (`lib/services/security/auto_lock_service.dart`, only with the
  app lock on and after onboarding; default 1 minute): "Immediate" locks
  the UI on `hidden`/`paused`, deliberately not on `inactive` (notification
  shade, system dialogs, app switcher, which FLAG_SECURE already covers); a
  timeout locks via a timer while the process runs and is re-checked on
  resume using the larger of a monotonic stopwatch and the wall clock. File
  pickers, share sheets, system prompts and Google sign-in run inside
  `ExternalUiGuard.run` and do not trigger the lock; a guard ends after 2
  minutes at the latest, so a platform call that never answers cannot
  switch the auto-lock off. After a guard ends the service waits 3 s
  (`resumeGrace`) for `resumed` before applying the lock, because the
  device-PIN screen reports its result before the app is resumed.
* Start-up failures: an I/O error while reading the file shows "Retry"; after
  three failed tries the reset is offered next to it. A file that is not a
  database, or one with a schema below v20 (development builds only; the
  upgrade steps from older schemas were removed), offers the reset at once,
  also next to "Retry".
* Onboarding's "Continue" checks for an existing database before deleting
  anything: one with accounts is kept (onboarding is marked done and the app
  goes to Home), one without accounts is opened and onboarding goes on to
  the first account; only a damaged one or one of an early test version is
  replaced (`SecuritySetupScreen`).

## Key derivation (sync passphrase, backup password)

Argon2id from `pointycastle` 4.0.0, run in a background isolate
(`deriveKey`, `lib/services/security/crypto/kdf.dart`). The implementation is
checked against the reference test vector (`test/services/security/crypto_test.dart`).

Measured on an Apple M4 (single thread), AOT-compiled Dart (as in release
builds), 3 runs each:

| Parameters | Time | Peak RSS |
| --- | --- | --- |
| m = 19 MiB, t = 2, p = 1 (OWASP minimum) | 73–80 ms | 50 MiB |
| m = 32 MiB, t = 3, p = 1 | 185–192 ms | 88 MiB |
| **m = 46 MiB, t = 2, p = 1 (chosen)** | **183–187 ms** | 121 MiB |
| m = 64 MiB, t = 2, p = 1 | 259–265 ms | 121 MiB |
| PBKDF2-HMAC-SHA256, 600,000 iterations | 4,508 ms (AOT), 1,340 ms (JIT) | – |

A mid-range phone core (e.g. Cortex-A78 class) is roughly 4–5× slower than
an M4 core for this workload, so the chosen parameters should take about
0.75–0.95 s per derivation (entering a sync passphrase or backup password),
within the 1.5 s budget. This is an estimate: it has
not been measured on a phone. Pure-Dart PBKDF2 at 600,000 iterations would
be several seconds on a phone, which is why Argon2id was chosen. The memory
cost was kept at 46 MiB (above OWASP's 19 MiB) rather than 64 MiB to leave
headroom on low-memory Android devices (the Dart implementation's peak
memory is about 2.5× m).

### Password rules

For the sync passphrase and the backup password: at least 10 characters,
not one of ~400 common passwords (also with a numeric suffix), with a local
strength meter (length, character classes, repeats, sequences).
`lib/services/security/password_policy.dart`. Nothing leaves the device.

## Operations

| Operation | What happens |
| --- | --- |
| Onboarding | Close any session, keep an existing database (see above) or replace a damaged one, open the session, save the app lock choice. |
| Start-up | Check the database file, open the session, then the app lock (if on). |
| Lock / auto-lock | UI only (`isAuthenticated = false`); the database stays open. |
| Backup | `VACUUM INTO` a temporary file, encrypt it (`BackupFormat`), delete the temporary file. |
| Restore | Decrypt into the temporary directory, validate, copy next to the live file, check, swap in, reopen. |
| Factory reset | Close the session, delete DB files, the stored automatic-backup password, exports and diagnostics, unpair Wi-Fi sync and delete the local sync files, clear preferences, sign out of Google Drive (best effort; offline it does not fail the reset). The automatic backup files are kept: after a reset forced by a database that cannot be opened they are what the user restores from. |

## Where secrets are stored

| Item | Location | Protection |
| --- | --- | --- |
| Database | app documents directory | Android sandbox and file-based encryption |
| Sync key | inside the database (`sync_kv`) | as the database; in backups under the backup password |
| Automatic-backup password | flutter_secure_storage 11 (`lz_auto_backup_password_v1`) | AES-GCM under an Android KeyStore key; lost with the key (`resetOnError`), then entered again |
| Wi-Fi pairing (pair key, sync passphrase) | flutter_secure_storage 11 (`lz_lan_pairing_v1`) | as above; lost with the key, then the phones pair again |
| Backup password, sync passphrase | never stored (except the automatic-backup password above) | – |

Neither secure-storage entry is backed up or moved to a new phone (see
[SECURITY.md](SECURITY.md#android-backup-and-moving-to-a-new-phone)).

## What is not protected

See [SECURITY.md](SECURITY.md#7-what-is-not-protected). In short: anything
that can read the app's private storage (code running as the app or as
root on a rooted or exploited phone) can read the database; the app lock
does not stop it. Losing the phone loses the data unless there is a backup
file somewhere else or a second synced phone.

## Supply chain

SQLite comes from the `sqlite3` package's build hook (the default source,
no `hooks:` setting in `pubspec.yaml`), which bundles `libsqlite3.so`. The
hook downloads a prebuilt library from the package's GitHub release and
verifies it against SHA-256 hashes compiled into the package
(`lib/src/hook/asset_hashes.dart`); the package itself is pinned by its hash
in `pubspec.lock`. Upgrading `sqlite3` changes both. `flutter test` uses
the same build. The cryptography of backups and sync is pure Dart
(`pointycastle`, `lib/services/security/crypto/`).
