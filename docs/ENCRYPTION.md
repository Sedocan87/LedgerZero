# Encryption Implementation

This document describes exactly what the code does. Source files are named
so you can check every statement.

## Overview

```
                 master password ──Argon2id──► KEK_pw ──┐
 160-bit recovery key ──HKDF-SHA256──► KEK_rk ──┐       │   AES-256-GCM wraps
 biometric hardware key (Keystore / Keychain) ──┼───────┼──────────────────┐
                                                ▼       ▼                  ▼
                                   random 256-bit data key (DEK)
                                                │
                       PRAGMA key = "x'<64 hex>'"  (raw key, no SQLCipher KDF)
                                                ▼
                               db.sqlite  (SQLCipher 4, AES-256)     
```

* The database is encrypted with a **random 256-bit data key (DEK)**
  generated at onboarding (`KeyVault.build`, `lib/services/security/key_vault.dart`).
* The DEK is never stored in plaintext. It is stored only **wrapped**
  (AES-256-GCM) by three independent keys:
  1. a key derived from the **master password** (Argon2id);
  2. a key derived from a random **recovery key** (HKDF-SHA256);
  3. optionally a **hardware key that needs a fresh biometric authentication**.
* The DEK reaches SQLCipher as a raw key: `PRAGMA key = "x'<64 hex>'"`, so
  SQLCipher uses it directly instead of running its own PBKDF2 over a
  passphrase (`lib/data/database/sqlcipher.dart`).

## The key vault (format v2)

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

### KDF choice and benchmark

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
0.75–0.95 s per unlock, within the 1.5 s budget. This is an estimate: it has
not been measured on a phone. Pure-Dart PBKDF2 at 600,000 iterations would
be several seconds on a phone, which is why Argon2id was chosen. The memory
cost was kept at 46 MiB (above OWASP's 19 MiB) rather than 64 MiB to leave
headroom on low-memory Android devices (the Dart implementation's peak
memory is about 2.5× m).

### Recovery key

160 random bits, shown as 32 Crockford-base32 characters in groups of four
(`7K3M-…`). Typing it back ignores case, spaces and dashes and reads O/I/L
as 0/1/1 (`lib/services/security/crypto/recovery_key.dart`). It is shown
during onboarding with an explicit "I have written down my recovery key"
step, and can be shown again or replaced in Settings > Security Settings >
Recovery Key after re-entering the password. It is deliberately not selectable and
has no copy button (the clipboard is readable by other apps and may sync).

### Biometric unlock

`lib/services/security/biometric_key_store.dart` (Dart) with native code in
`android/app/src/main/kotlin/com/ledgerzero/app/BiometricKeyChannel.kt` and
`ios/Runner/AppDelegate.swift`. No third-party plugin is used: the
maintained options either cache the authentication for the life of the
process (flutter_secure_storage 10 on Android) or are unmaintained
(biometric_storage, last release 2024).

* **Android:** an AES-256-GCM key in the Android Keystore with
  `setUserAuthenticationRequired(true)`, per-use authentication
  (`setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)` on API 30+,
  validity −1 below) and `setInvalidatedByBiometricEnrollment(true)`. The
  DEK is encrypted and decrypted only through a `BiometricPrompt.CryptoObject`
  bound to that key, so every unlock requires a strong biometric. Only IV +
  ciphertext are stored (app-private SharedPreferences).
* **iOS:** a keychain item with access control `.biometryCurrentSet` and
  `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`; every read shows Face ID
  / Touch ID. Enabling first asks for biometric confirmation.
* Enrolling a new fingerprint/face invalidates the key; the app deletes it
  and asks the user to unlock with the password and enable biometrics again.
* A biometric DEK is checked against the vault before use (a stale key from
  an older vault is rejected and deleted).

### Password rules

At least 10 characters, not one of ~400 common passwords (also with a
numeric suffix), with a local strength meter (length, character classes,
repeats, sequences). `lib/services/security/password_policy.dart`. Nothing
leaves the device.

## Operations

| Operation | What happens |
| --- | --- |
| Onboarding | Build vault in memory (new DEK + recovery key) → show recovery key → on "I saved it": delete leftover DB files, save vault (1 write), unlock session, optionally store DEK in the biometric store. |
| Password unlock | Argon2id → unwrap → check the DEK opens the DB file (`SqlCipher.canOpen`) → session. |
| Recovery unlock | HKDF → unwrap → check DB → user must set a new password (re-wrap, 1 write) before the app opens. The recovery key stays valid. |
| Biometric unlock | Hardware-gated read → check against vault and DB → session. |
| Password change | Unwrap with the old password, re-wrap with the new one, 1 write. **No `PRAGMA rekey`.** Recovery key and biometric key stay valid. |
| New recovery key | Re-authenticate with the password, show new key, on "I saved it" replace the recovery wrap (1 write). The old key stops working. |
| Factory reset | Lock, delete DB files, vault, legacy entries, biometric key, exports and diagnostics, clear preferences. |

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

The "Encrypted" indicator (Encryption Status) in Settings > Security
Settings is shown only when
SQLCipher is linked **and** the file on disk does not start with the plain
SQLite header (`databaseEncryptionStatusProvider`).

## Session and locking

* `sessionProvider` (`lib/presentation/providers/session_provider.dart`)
  owns the DEK. There is no static key and no static database instance.
* `databaseProvider` opens a connection keyed with the session key and
  closes it when the key changes or on dispose.
* `SessionController.lock()` closes the connection, zeroes the key bytes and
  sets the state to locked. **`appLockStateProvider`** exposes
  `AppLockState.locked/unlocked`; services that must stop while locked
  (the sync controller) listen to it.
* Auto-lock (`lib/services/security/auto_lock_service.dart`): "Immediate"
  locks on `inactive`/`hidden`/`paused`; a timeout locks via a timer while
  the process runs and is re-checked on resume using the larger of a
  monotonic stopwatch and the wall clock (moving the clock back cannot
  extend a session; device sleep is still counted). File pickers, share
  sheets, biometric prompts and Google sign-in run inside
  `ExternalUiGuard.run` and do not trigger the lock.

## Legacy installs (before v2)

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
5. show the new recovery key (old "recovery keys" were the derived key and
   no longer work) and ask the user to re-enable biometrics.

Every interruption is recoverable with the same password: at login a
pending vault is unwrapped and the database is tried with the new key and
then with the legacy key (re-keying if needed). Tested against real SQLCipher
databases in `test/services/security/unlock_service_test.dart`.

## Where secrets are stored

| Item | Location | Protection |
| --- | --- | --- |
| Wrapped DEK (vault) | flutter_secure_storage 10: iOS Keychain `first_unlock_this_device`; Android AES-GCM data under a Keystore RSA key, `resetOnError: false` | AES-256-GCM under password / recovery key |
| Biometric DEK | Android Keystore-bound ciphertext / iOS keychain item | hardware, biometric per use |
| DEK in memory | `DatabaseKey` in `sessionProvider` | zeroed on lock (Dart strings and native copies cannot be zeroed from Dart) |
| Database | app documents directory | SQLCipher AES-256 with the DEK |

## What is not protected

* **Sync files** in the cloud folder are AES-256-GCM encrypted with a key
  derived from the sync passphrase (Argon2id with the parameters above, then
  HKDF-SHA256 bound to the folder's sync id); only file names, sizes and the
  authenticated headers are visible. See [DELTA_FORMAT.md](DELTA_FORMAT.md).
* A device that is unlocked **and** has the app unlocked exposes the data
  to whoever holds it.
* Malware with root/jailbreak access to a running, unlocked app can read
  process memory.
* JSON/CSV/PDF exports are plaintext by design (written to the temporary
  directory and deleted after sharing, see [SECURITY.md](SECURITY.md)).

## Supply chain

SQLCipher comes from the `sqlite3` package's build hook
(`hooks.user_defines.sqlite3.source: sqlcipher` in `pubspec.yaml`). The hook
downloads a prebuilt library from the package's GitHub release and verifies
it against SHA-256 hashes compiled into the package
(`lib/src/hook/asset_hashes.dart`); the package itself is pinned by its hash
in `pubspec.lock`. Upgrading `sqlite3` changes both. `flutter test` uses the
same SQLCipher build, so the tests above run against real SQLCipher.
