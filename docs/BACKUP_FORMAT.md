# LedgerZero Backup Format Specification

LedgerZero backups (`.lzbk`) are always encrypted. There is no plaintext
backup format any more; for a readable copy use the JSON or CSV export.
Implementation: `lib/services/backup/backup_format.dart`.

## Version 2 (current)

```
offset  size  content
0       4     magic "LZBK"
4       1     format version = 0x02
5       4     header length H (unsigned 32-bit, big-endian)
9       H     header, UTF-8 JSON
9+H     ...   records: [length L (u32 BE)] [L bytes: AES-256-GCM ciphertext + 16-byte tag]
```

### Header

```json
{
  "format": "ledgerzero-backup",
  "kdf": {"alg": "argon2id", "v": 19, "m": 47104, "t": 2, "p": 1, "salt": "<base64, 16 bytes>"},
  "cipher": "aes-256-gcm-stream",
  "nonce_prefix": "<base64, 7 bytes>",
  "chunk_size": 1048576,
  "compression": "gzip",
  "schema_version": 18,
  "created_at": "2026-10-16T12:00:00.000Z"
}
```

* **Key**: `Argon2id(backup password, salt, m, t, p)`, 32 bytes. The same
  KDF and default cost as the master-password key (see
  [ENCRYPTION.md](ENCRYPTION.md)); the parameters are read from the header,
  so they can be raised in later versions. `"alg": "pbkdf2-sha256"` with
  `"i"` iterations is also accepted.
* **Plaintext**: a gzip stream of a plain (unencrypted) SQLite database,
  split into chunks of `chunk_size` bytes (the last chunk may be shorter,
  and is empty if the stream length is an exact multiple).
* **Chunk *i*** is encrypted with AES-256-GCM, nonce
  `nonce_prefix (7 bytes) || i (4 bytes BE) || last (1 byte: 0x01 for the
  final chunk, else 0x00)` and the complete header bytes (offsets 0 to
  9+H) as associated data.

This is the STREAM construction: modifying the header, reordering, dropping
or duplicating chunks, truncating the file or appending data all fail
authentication. Every backup has a fresh salt and therefore a fresh key, so
nonces are never reused. Encryption and decryption stream the data; memory
use is bounded by the chunk size.

### Contents

The database is exported with `ATTACH DATABASE ... KEY ''` and
`SELECT sqlcipher_export(...)`, so it is a plain SQLite file independent of
the device key (`VACUUM INTO` would have copied the device key). The
schema version (`PRAGMA user_version`) is preserved.

## Version 1 (read only)

Files written before format v2 have no header:

| Component | Length |
| --- | --- |
| Salt | 32 bytes |
| IV | 12 bytes |
| AES-256-GCM(gzip(database)) + tag | rest |

Key: PBKDF2-HMAC-SHA256(password, salt, 100,000 iterations, 32 bytes).
These files can still be restored. Note: v1 backups made by an install whose
database was encrypted contain a database that is still encrypted with that
install's old key (the old code used `VACUUM INTO`); such files cannot be
restored and are reported as "not a LedgerZero backup that can be restored".

## Restore

1. Decrypt into the app's temporary directory.
2. Validate: `PRAGMA integrity_check`, required tables (accounts,
   transactions, categories, category_groups, budgets, payees),
   `user_version` between 1 and the current schema version. A backup from a
   newer version is refused.
3. Older schemas are migrated by opening the file through `AppDatabase`.
4. `pending_sync_changes` is emptied.
5. A new database encrypted with the current device data key is built next
   to the live file (`ATTACH ... KEY "x'..'"` + `sqlcipher_export`) and
   checked.
6. The connection is closed, the live file is moved to `<db>.previous`, the
   new file is moved into place and reopened, and a query is run. On success
   `<db>.previous` is deleted; on failure it is moved back and reopened.
7. The temporary plain file is always deleted. Queued (not yet uploaded)
   sync change files are deleted and `sync_rebootstrap_required` is set (see
   [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md)).

Selective restore (merge transactions from a date range) decrypts and
validates the same way and reads the plain file directly, without replacing
the live database.
