# LedgerZero Backup Format Specification

This document describes the format of LedgerZero backup files (`.lzbk` and `.sqlite`).

## Overview

LedgerZero supports two types of backups:
1. **Unencrypted Backups**: Standard SQLite database files (`.sqlite`).
2. **Encrypted Backups**: AES-GCM encrypted containers (`.lzbk`).

## Unencrypted Backup (`.sqlite`)

*   **Extension**: `.sqlite`
*   **Format**: Standard SQLite 3 database file.
*   **Contents**: A complete snapshot of the user's local database, created via `VACUUM INTO`.
*   **Warning**: These files contain sensitive financial data in plaintext (if opened with a standard SQLite viewer) or encrypted with the original device-specific key (if simple copy), but our implementation uses `VACUUM INTO` to a plaintext target to ensure portability, meaning unencrypted backups are truly unencrypted and portable.

## Encrypted Backup (`.lzbk`)

*   **Extension**: `.lzbk`
*   **Format**: Binary file containing salt, IV, and encrypted data.
*   **Encryption Algorithm**: AES-256-GCM.
*   **Key Derivation**: PBKDF2 (HMAC-SHA256).

### File Structure

The file is a continuous byte stream structured as follows:

| Component | Length | Description |
| :--- | :--- | :--- |
| **Salt** | 32 bytes | Random salt used for key derivation. |
| **IV** | 12 bytes | Initialization Vector (Nonce) for AES-GCM. |
| **Ciphertext** | Variable | The encrypted SQLite database file. |

### Encryption Details

*   **Algorithm**: AES (Advanced Encryption Standard).
*   **Mode**: GCM (Galois/Counter Mode).
*   **Key Size**: 256 bits.
*   **MAC Size**: 128 bits (appended to ciphertext by GCM implementation).

### Key Derivation Details

*   **Algorithm**: PBKDF2 (Password-Based Key Derivation Function 2).
*   **PRF**: HMAC-SHA256.
*   **Iterations**: 100,000.
*   **Salt**: Read from the file header (first 32 bytes).
*   **Password**: User-provided string (UTF-8 encoded).
*   **Derived Key Length**: 32 bytes (256 bits).

### Restoration Process

1.  Read the first 32 bytes as **Salt**.
2.  Read the next 12 bytes as **IV**.
3.  Read the remaining bytes as **Ciphertext**.
4.  Derive the **Key** using the user's password and the extracted **Salt**.
5.  Initialize AES-GCM with the **Key** and **IV**.
6.  Decrypt the **Ciphertext**.
7.  The result is a standard SQLite database file, which can be validated via `PRAGMA integrity_check`.

## Versioning

Currently, there is no explicit version header in the file. Future versions may append a magic number or version byte at the beginning of the file.
