# LedgerZero Security Architecture

## Overview

LedgerZero is a "Local-First" personal finance application designed with privacy and sovereignty as its core principles. This document outlines the security measures implemented to protect user data.

## 1. Data Encryption

### Encryption at Rest (SQLCipher)
- **Database**: The entire SQLite database is encrypted using SQLCipher (AES-256).
- **Key Derivation**: Encryption keys are derived using PBKDF2-HMAC-SHA256 with 100,000 iterations and a random 32-byte salt.
- **Key Management**:
  - Keys are never stored in plain text.
  - On mobile devices (iOS/Android), `flutter_secure_storage` is used to store keys when biometric authentication is enabled, leveraging the platform's secure hardware (Keychain/Keystore).
  - Session keys are held in memory only while the app is unlocked and are cleared immediately upon locking.

### Encrypted Backups
- **Format**: AES-GCM encrypted files (`.lzbk`).
- **Structure**: `[Salt (32 bytes)] [IV (12 bytes)] [GZip Compressed & Encrypted Data]`.
- **Security**: Allows users to create password-protected backups that are safe to store on insecure cloud providers.

## 2. Authentication & Session Management

- **Biometrics**: Supports Fingerprint and Face ID via `local_auth`.
- **Auto-Lock**: Configurable auto-lock timer clears the session encryption key from memory after a period of inactivity (detected via app lifecycle state).
- **Recovery Key**: A master recovery key mechanism allows access if the password is lost, provided the user has safely stored the key.

## 3. Cloud Synchronization Security

- **Provider Agnostic**: Users bring their own cloud storage (Google Drive, iCloud).
- **Least Privilege**:
  - **Google Drive**: Uses `drive.file` scope, granting access *only* to files created by LedgerZero. The app cannot read other user files.
- **Data Format**: Synchronization uses "Delta Files" (JSON logs of changes).
- **Traffic**: All traffic is encrypted in transit (HTTPS) by the respective cloud provider SDKs.

## 4. Application Security

- **Obfuscation**: Android release builds utilize R8 (`isMinifyEnabled = true`) for code shrinking and obfuscation.
- **Secure Randomness**: All cryptographic operations (Key generation, IVs, Salts) utilize `Random.secure()` from `dart:math` or the `pointycastle` library.
- **Input Validation**: Database queries use parameterized inputs (via Drift) to prevent SQL injection.
- **Clipboard**: Sensitive data (like Recovery Keys) is only copied to the clipboard via explicit user action.

## 5. Privacy

- **No Analytics**: The application contains no tracking or analytics SDKs.
- **Offline First**: The app functions completely offline; internet is only used for user-configured synchronization.
- **Temporary Files**: Temporary files used during export or sync are cleaned up immediately after use.
