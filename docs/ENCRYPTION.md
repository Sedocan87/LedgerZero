# Encryption Implementation

This document describes exactly what the code does. Source files are named
so you can check every statement.

## Overview

```
 Android KeyStore key (no user authentication)
        │ AES-GCM (flutter_secure_storage 10)
        ▼
 random 256-bit data key (DEK)          app lock: BiometricPrompt
        │                               (fingerprint/face/device PIN)
        │ PRAGMA key = "x'<64 hex>'"    gates the UI only
        ▼
 db.sqlite  (SQLCipher 4, AES-256)
```

* The database is encrypted with a **random 256-bit data key (DEK)**
  generated at onboarding (`DeviceKeyStore.create`,
  `lib/services/security/device_key_store.dart`).
* The DEK is stored by flutter_secure_storage 10 under the entry
  `lz_device_dek_v1`: AES-GCM data under a KeyStore-held key that needs no
  user authentication, `resetOnError: false` (a KeyStore error is reported
  instead of silently erasing the key). There is no master password, so the
  database can be opened whenever the app runs: also behind the app lock,
  for sync, card capture and scheduled transactions.
* The DEK reaches SQLCipher as a raw key: `PRAGMA key = "x'<64 hex>'"`, so
  SQLCipher uses it directly instead of running its own PBKDF2 over a
  passphrase (`lib/data/database/sqlcipher.dart`).
* Anything that leaves the device stays end-to-end encrypted with its own
  secret: sync files (sync passphrase / QR pairing) and backups (backup
  password).

Why no master password: losing it (and the recovery key) lost all data,
which for a budgeting app is far likelier than the attack it prevents
(reading the database with code running as the app on a rooted or
exploited phone while the app is locked). Android's file-based encryption,
the app sandbox, `allowBackup="false"` and the app lock cover the realistic
cases. See [SECURITY.md](SECURITY.md#7-what-is-not-protected).

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
  start: it reads the DEK, checks it opens an existing database file
  (`SqlCipher.canOpen`), opens the session (`sessionProvider`) and then
  shows the app lock if it is on.
* `sessionProvider` (`lib/presentation/providers/session_provider.dart`)
  owns the DEK. There is no static key and no static database instance.
  `databaseProvider` opens a connection keyed with the session key and
  closes it when the key changes or on dispose. `SessionController.close()`
  closes the connection, zeroes the key bytes and sets the state to closed;
  only a factory reset closes it.
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
* No DEK: if a master-password vault exists, the one-time migration below
  runs; otherwise the lock screen offers a factory reset (then restore a
  backup or sync again).
* The key store throws (`resetOnError: false`, so flutter_secure_storage
  reports instead of erasing): the lock screen retries three times with a
  short delay, then shows "Retry"; after three such starts, or at once when
  the error names a permanent KeyStore condition (`BadPaddingException`,
  `AEADBadTagException`, `UnrecoverableKeyException`, `KeyStoreException`,
  `InvalidKeyException`, `KeyPermanentlyInvalidatedException`), it explains
  that the key store no longer holds the key and offers the reset next to
  "Retry". An I/O error while checking the database file is handled the
  same way (retryable first); only a key that does not open the file leads
  straight to the reset, which now also has "Retry".
* Onboarding's "Continue" checks for an existing database that the stored
  DEK opens before deleting anything; when found, it opens the session on
  it, marks onboarding done and goes to Home (`SecuritySetupScreen`).

## Opening the database (fail closed)

`openEncryptedConnection(dek)` (`lib/data/database/connection_native.dart`):

1. refuses to run if the loaded library is not SQLCipher
   (`PRAGMA cipher_version` empty → `EncryptionUnavailableException`);
2. runs `PRAGMA key = "x'<hex>'"` (the hex is generated from bytes; only
   `[0-9a-f]` can appear);
3. proves the key with `SELECT count(*) FROM sqlite_master`, otherwise throws
   `DatabaseKeyException`.

There is no unkeyed fallback: without a session key, `databaseProvider`
throws `DatabaseLockedException`. The copy of the key passed to the
connection is zeroed after keying; SQLCipher keeps its own copy for the
life of the connection and wipes it when the connection closes.

The "Encrypted" indicator (Encryption Status) in Settings > Security is
shown only when SQLCipher is linked **and** the file on disk does not start
with the plain SQLite header (`databaseEncryptionStatusProvider`).

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
0.75–0.95 s per derivation (entering a sync passphrase or backup password,
and the one-time unlock of a master-password install), within the 1.5 s
budget. This is an estimate: it has
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
| Onboarding | Close any session, delete leftover database files and key material of older versions, generate and store a new DEK, open the session, save the app lock choice. |
| Start-up | Read the DEK, check it opens the database, open the session, then the app lock (if on). |
| Lock / auto-lock | UI only (`isAuthenticated = false`); the database stays open. |
| Factory reset | Close the session, delete DB files, the DEK and any old vault / legacy / biometric entries, the stored automatic-backup password, exports and diagnostics, clear preferences. The automatic backup files are kept: after a reset forced by a lost DEK they are what the user restores from. |

## Where secrets are stored

| Item | Location | Protection |
| --- | --- | --- |
| DEK | flutter_secure_storage 10 (`lz_device_dek_v1`) | AES-GCM under an Android KeyStore key, no user authentication |
| DEK in memory | `DatabaseKey` in `sessionProvider` | zeroed when the session closes (Dart strings and native copies cannot be zeroed from Dart) |
| Database | app documents directory | SQLCipher AES-256 with the DEK |
| Sync key | inside the database (`sync_kv`) | the database encryption |

## Migration from master-password installs

Versions before the device key wrapped the DEK by a master password, a
recovery key and optionally a biometric key (the key vault, format v2), and
the first versions (pre-v2) derived the database key from the password.
Such an install starts at the one-time unlock (`LegacyUnlockView`,
`lib/presentation/screens/legacy_unlock_view.dart`): the existing
`UnlockService` recovers the DEK with the password, the recovery key or the
biometric key (pre-v2 installs are re-keyed to a new random DEK on the way,
see below), then `LegacyKeyMigration.adopt`
(`lib/services/security/legacy_key_migration.dart`) writes it to the device
key store **first** and only then deletes the vault, the legacy entries and
the biometric key. The database keeps its key and is not rewritten. An
interruption after the write leaves old entries behind, which the next start
deletes. After the migration the app lock is turned on when the phone has a
screen lock (the user had a password before).

This code (`KeyVault`, `UnlockService`, `LegacyKeyMaterial`,
`BiometricKeyStore`, `BiometricKeyChannel.kt`) creates nothing new except
the intermediate vault of a pre-v2 migration; it can be removed once no
install from before the device key is left.

### Key vault (format v2)

Stored under the single secure-storage entry `lz_key_vault_v2` as JSON
(`VaultRecord`):

| Field | Content |
| --- | --- |
| `password.kdf` | `{"alg":"argon2id","v":19,"m":47104,"t":2,"p":1,"salt":…}` |
| `password.nonce`, `password.ct` | AES-256-GCM(KEK_pw, DEK), AAD = `ledgerzero/dek/password/v2` + canonical KDF JSON |
| `recovery.salt`, `.nonce`, `.ct` | AES-256-GCM(KEK_rk, DEK), KEK_rk = HKDF-SHA256(recovery key, salt, `ledgerzero/recovery-kek/v2`) |
| `recoveryKey.nonce`, `.ct` | AES-256-GCM(DEK, recovery key): lets Settings show the recovery key again after re-authentication; grants nothing beyond the DEK it is encrypted with |
| `legacyMigrationPending` | only while a legacy database is being re-keyed |

Properties:

* **Wrong password = GCM authentication failure.** There is no verifier hash
  (the old SHA-256-of-the-key verifier was an offline guessing oracle and is
  gone).
* The KDF parameters are part of the AAD: replacing them with weaker values
  makes the unwrap fail.
* Algorithm, parameters and salt are stored with the blob, so the cost can be
  raised later (re-wrap on the next password entry) without breaking
  existing installs. PBKDF2-HMAC-SHA256 is also supported for reading
  (and for new keys only with ≥ 600,000 iterations).
* All writes of the vault are a **single** secure-storage write.

### Recovery key (read only)

160 random bits, shown as 32 Crockford-base32 characters in groups of four
(`7K3M-…`). Typing it back ignores case, spaces and dashes and reads O/I/L
as 0/1/1 (`lib/services/security/crypto/recovery_key.dart`). Older versions
showed it at onboarding; now it is only accepted by the one-time unlock.

### Pre-v2 installs

The previous design derived the database key from the password
(`base64url(PBKDF2-HMAC-SHA256(password, salt, 100,000))`), stored salt and
a SHA-256 verifier, keyed SQLCipher with that string as a passphrase, and
stored the key itself for biometrics.

On the first successful password login (`UnlockService._migrateLegacy`):

1. derive the old key, check it against the verifier and the database;
2. build a vault for a **new random DEK** and save it marked
   `legacyMigrationPending`;
3. `PRAGMA rekey` the database to the raw DEK (the only place `rekey` is
   used) and verify it opens;
4. clear the marker, delete the legacy salt, verifier and plaintext
   biometric key;
5. the new DEK then moves to the device key store like any other.

Every interruption is recoverable with the same password: at login a
pending vault is unwrapped and the database is tried with the new key and
then with the legacy key (re-keying if needed). Tested against real SQLCipher
databases in `test/services/security/unlock_service_test.dart`.

## What is not protected

See [SECURITY.md](SECURITY.md#7-what-is-not-protected). In short: code
running as the app on a rooted or exploited phone can open the database
(the device key needs no authentication); the app lock does not stop it.
Losing the phone loses the data unless there is a backup or a second synced
phone.

## Supply chain

SQLCipher comes from the `sqlite3` package's build hook
(`hooks.user_defines.sqlite3.source: sqlcipher` in `pubspec.yaml`). The hook
downloads a prebuilt library from the package's GitHub release and verifies
it against SHA-256 hashes compiled into the package
(`lib/src/hook/asset_hashes.dart`); the package itself is pinned by its hash
in `pubspec.lock`. Upgrading `sqlite3` changes both. `flutter test` uses the
same SQLCipher build, so the tests above run against real SQLCipher.
