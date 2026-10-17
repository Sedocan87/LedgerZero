# Encryption Troubleshooting Guide

LedgerZero encrypts its database with SQLCipher (AES-256) using a random
data key that Android's secure key store keeps for the app. There is no
master password; the optional app lock uses your fingerprint, face or
screen lock. See [ENCRYPTION.md](ENCRYPTION.md).

## The app lock does not appear or cannot be turned on

* The app lock needs a screen lock (PIN, pattern or password) on the phone.
  Set one up in the Android settings, then turn the lock on in
  **Settings > Security**. Turning it on asks for your fingerprint, face or
  screen lock once.
* "This phone has no screen lock any more, so the app lock was turned off":
  the screen lock was removed in the Android settings. Set one up again and
  turn the app lock back on.

## "Unlock one last time"

Shown once after updating from a version that used a master password.
Unlock with your master password (or **Use recovery key**, or biometrics if
they were on). The app then keeps its key in the phone's secure key store
and never asks for the password again; the app lock is turned on if the
phone has a screen lock.

* "Incorrect Password": check Caps Lock and the keyboard layout; use the eye
  icon to see what you typed.
* The recovery key has 32 characters in groups of four. Case, spaces and
  dashes do not matter; `O` is read as `0`, `I` and `L` as `1`.
* "An update is still being completed": unlock once with your password; the
  recovery key works afterwards.

## "LedgerZero cannot open your data"

The key stored on this phone is missing or does not match the database
file, for example after clearing the app's storage, copying a database file
from another phone, or a damaged file. The data cannot be opened without
that key.

The screen offers **Reset app**. It asks you to type a confirmation word
(`RESET`; German `ZURÜCKSETZEN`) and then runs the same factory reset as
**Settings > Factory Reset**: it deletes the database with its
`-wal`/`-shm` files, the stored key, exported files, local crash reports and
all preferences, and opens onboarding. Set the app up again, then restore a
backup in **Settings > Backup & Export** or sync again from your other
phone. (Deleting and reinstalling the app has the same effect.)

To be safe, keep a recent backup or a second synced phone: the key never
leaves this phone, so a lost or reset phone means lost data otherwise.

## Settings shows "The database file is NOT encrypted"

This should never happen in a release build: the app refuses to open a
database without SQLCipher. If you see it, the build was made without
`hooks.user_defines.sqlite3.source: sqlcipher` in `pubspec.yaml`; please
report it.

## Backups

* Backups always need the backup password chosen when the backup was made.
* "This backup was made by a newer version": update the app first.
* Old backups (before format v2) made by an encrypted install cannot be
  restored; see [BACKUP_FORMAT.md](BACKUP_FORMAT.md).

## Performance

Entering a backup password or sync passphrase takes up to about a second on
a mid-range phone: that is the deliberate cost of Argon2id key derivation,
which makes guessing them expensive. Opening the app and day-to-day
database access are not affected.
