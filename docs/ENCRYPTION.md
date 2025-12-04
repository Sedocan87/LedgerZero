# Encryption Implementation

## Architecture
LedgerZero uses **SQLCipher** (via `sqlcipher_flutter_libs` and `drift`) to provide full-database encryption at rest using AES-256.

### Key Components
1.  **SecurityManager**: Handles key generation, derivation, and secure storage.
2.  **AppDatabase**: Configures Drift to use the encryption key via `PRAGMA key`.
3.  **FlutterSecureStorage**: Stores the encryption key (wrapped) or salt/verifier.
4.  **LocalAuth**: specific biometric authentication to unlock the key from storage.

## Key Management

### 1. Key Generation
- A random 256-bit (32-byte) key is generated using `Random.secure()`.
- This key is the **Database Encryption Key (DEK)**. It never changes for the lifetime of the database (unless `rekey` is performed).

### 2. Password Derivation
- When a user sets a Master Password, we **do not** use the password directly as the DEK.
- Instead, we use the password to **encrypt** (or gate access to) the DEK, or in the current simple implementation, we derive a key from the password to use as the DEK (Note: The current implementation derives the key from password. If password changes, we must re-encrypt the database).
- **Derivation Algorithm**: PBKDF2-HMAC-SHA256.
- **Iterations**: Default 100,000 (configurable).
- **Salt**: Random salt stored in SecureStorage.

### 3. Biometrics
- If Biometrics is enabled, the DEK is stored in `FlutterSecureStorage`.
- Accessing this storage requires Biometric authentication (on supported platforms).

### 4. Session Key
- `SecurityManager.sessionKey` holds the DEK in memory while the app is unlocked.
- This static variable is cleared when the app locks or terminates.

## Database Connection
- `NativeDatabase` is used.
- In the `setup` callback, `PRAGMA key = '...'` is executed immediately if `sessionKey` is present.
- On Desktop (Linux), `open.overrideFor` is required to load `libsqlcipher.so` instead of standard `libsqlite3.so`.

## Security guarantees
- **At Rest**: The `db.sqlite` file is fully encrypted. Headers are randomized.
- **In Memory**: The key is held in memory.
- **Key Storage**: The key is never stored in plain text on disk. It is either derived from user input (Password) or stored in hardware-backed SecureStorage.

## Recovery
- A **Recovery Key** (the raw DEK encoded in Base64) can be revealed to the user.
- This key can be used to unlock the database bypassing the password derivation step, effectively acting as a "Master Key".

## Performance
- Overhead is approximately 50% for write operations compared to plain SQLite.
- Read performance impact is negligible for typical usage.
