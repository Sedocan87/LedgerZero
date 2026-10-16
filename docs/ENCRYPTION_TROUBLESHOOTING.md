# Encryption Troubleshooting Guide

LedgerZero encrypts its database with SQLCipher (AES-256) using a random
data key. Your master password, your recovery key and (optionally)
biometrics each unlock that data key. See [ENCRYPTION.md](ENCRYPTION.md).

## "Incorrect Password"

The password did not unlock the data key.

* Check Caps Lock and the keyboard layout; use the eye icon to see what you
  typed.
* If you changed the password, use the new one. The database itself never
  changes when you change the password.
* If you forgot it, tap **Use recovery key** on the login screen.

## Recovery key

* Unlocking with the recovery key asks you to set a new master password
  before the app opens. The recovery key keeps working afterwards.
* It has 32 characters in groups of four. Case, spaces and dashes do not
  matter; `O` is read as `0`, `I` and `L` as `1`.
* "This recovery key is not correct": check each group. If you created a new
  recovery key in Settings, only the newest one works.
* After updating from a version before the new key design, the app shows a
  **new** recovery key once. Keys saved before that update no longer work.
* "An update is still being completed": unlock once with your password; the
  recovery key works afterwards.

## Biometrics

* "Biometric unlock was turned off because the biometrics on this device
  changed": adding or removing a fingerprint or face invalidates the
  hardware key on purpose. Unlock with your password and turn biometrics on
  again in Settings > Security Settings.
* Biometric unlock needs a device passcode/PIN and an enrolled strong
  biometric (Android Class 3; Face ID / Touch ID on iOS).
* After updating from an older version, biometrics are turned off once and
  must be enabled again.

## "Your key is correct, but the database file could not be opened"

The data key was unlocked but does not match the database file, for example
after copying a database file from another device or a damaged file.
Restore a backup (`.lzbk`) instead of copying database files.

## "The key data of this app is missing"

The secure storage that holds the wrapped data key is empty, e.g. after
restoring an iPhone backup to a new device (keychain items are
device-only) or clearing app storage on Android. The database cannot be
unlocked without it, not even with the recovery key (it unwraps the key
stored there).

The login screen shows this message after an unlock attempt, together with
a **Reset app** button. It asks you to type a confirmation word (`RESET`;
German `ZURÜCKSETZEN`) and then runs the same factory reset as **Settings >
Factory Reset**: it deletes the database with its `-wal`/`-shm` files, the
key vault, legacy and biometric key entries, exported files, local crash
reports and all preferences, and opens onboarding. Set the app up again and
restore a backup in **Settings > Backup & Export**. (Deleting and
reinstalling the app, or clearing its storage on Android, has the same
effect.)

## Settings shows "The database file is NOT encrypted"

This should never happen in a release build: the app refuses to open a
database without SQLCipher. If you see it, the build was made without
`hooks.user_defines.sqlite3.source: sqlcipher` in `pubspec.yaml`; please
report it.

## Backups

* Backups always need the backup password chosen when the backup was made
  (not necessarily your master password).
* "This backup was made by a newer version": update the app first.
* Old backups (before format v2) made by an encrypted install cannot be
  restored; see [BACKUP_FORMAT.md](BACKUP_FORMAT.md).

## Performance

Unlocking takes up to about a second on a mid-range phone: that is the
deliberate cost of Argon2id key derivation, which makes guessing passwords
expensive. Day-to-day database access is not affected.
