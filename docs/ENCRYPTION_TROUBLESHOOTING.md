# Encryption Troubleshooting Guide

## Overview
LedgerZero uses SQLCipher (AES-256) to encrypt your local database. This ensures your financial data remains private even if your device is compromised.

## Common Issues

### 1. Database Locked / Invalid Password
**Symptom:** App asks for password but says "Invalid Password" even if you believe it is correct.
**Possible Causes:**
- Typo in password.
- Caps Lock is on.
- Password was changed on another device (if manually synced database file).

**Solution:**
- Try typing the password slowly and checking for visibility toggle.
- If you have your **Recovery Key**, use the "Use Recovery Key" option on the login screen.

### 2. Biometrics Not Working
**Symptom:** "Biometric setup failed" or prompt doesn't appear.
**Possible Causes:**
- Device biometric settings changed (e.g., new fingerprint added).
- App permissions for FaceID/Fingerprint revoked.
- Hardware unavailable.

**Solution:**
- Go to device settings and verify Biometric permissions for LedgerZero.
- Use your Master Password to login, then toggle Biometrics OFF and ON again in Settings > Security.

### 3. "File is not a database" Error
**Symptom:** App crashes or shows error `file is not a database`.
**Cause:**
- The database file is encrypted but the app is trying to open it without the key (or with wrong key).
- This can happen if the `sqlcipher` library is not loaded correctly on Desktop (Linux/Windows).

**Solution:**
- **Linux:** Ensure `libsqlcipher` is installed (`sudo apt install sqlcipher`).
- **Restart App:** Force close and restart to ensure clean state.

### 4. Performance Issues
**Symptom:** App is slow to unlock or save transactions.
**Cause:**
- Encryption adds overhead (decryption/encryption on every disk IO).
- Key derivation (PBKDF2) takes time to prevent brute-force attacks.

**Solution:**
- This is generally normal behavior for secure apps.
- If it becomes unusable, check if other background processes are consuming CPU.

## Advanced Recovery

### Using the Recovery Key
If you have lost your Master Password, you MUST have your **Recovery Key** (a long alphanumeric string) that you backed up during setup.

1. On the Login Screen, tap **Use Recovery Key**.
2. Paste your Recovery Key.
3. Tap **Unlock**.
4. Immediately go to **Settings > Change Password** to set a new Master Password.

### Data Restoration from Backup
If you cannot unlock your database at all:
1. Uninstall and Reinstall the app (Warning: This deletes local data!).
2. If you have a CSV export or Backup file, you can import it.
3. If you have a synced database file on Cloud, ensure you know the password associated with *that* file.

## Contact Support
If issues persist and you believe it's a bug, check logs (if enabled) or contact support with:
- App Version
- Platform (iOS, Android, Linux, etc.)
- Error Message Screenshot
