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
  KDF and default cost as the sync passphrase (see
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

The database is copied with `VACUUM INTO` into a temporary file (a
consistent snapshot of the open database). The schema version (`PRAGMA
user_version`) is preserved.

## Version 1 (read only)

Files written before format v2 have no header:

| Component | Length |
| --- | --- |
| Salt | 32 bytes |
| IV | 12 bytes |
| AES-256-GCM(gzip(database)) + tag | rest |

Key: PBKDF2-HMAC-SHA256(password, salt, 100,000 iterations, 32 bytes).
These files can still be decrypted, but they were written by development
builds with a schema below v20, so the restore refuses them (see below).

## Restore

1. Decrypt into the app's temporary directory.
2. Validate: `PRAGMA integrity_check`, required tables (accounts,
   transactions, categories, category_groups, budgets, payees),
   `user_version` between 20 (`AppDatabase.minimumSchemaVersion`) and the
   current schema version. A backup from a newer version is refused
   (`BackupTooNewException`); one below v20 comes only from development
   builds and is refused too (`BackupTooOldException`, "made by an early
   test version"): older schemas are not upgraded any more.
3. `pending_sync_changes` is emptied and `sync_kv.device_id` removed (the
   restoring phone keeps its own sync device id).
4. The backup is inspected (member id, personal accounts, creation time)
   so the app can warn before replacing the data
   (`RestoreService.prepareRestore`; see BACKUP_AND_EXPORT.md).
5. The file is copied next to the live file (`<db>.restore-new`) and the
   copy is checked (`integrity_check`), on a background isolate.
6. Sync is paused and `sync_rebootstrap_required` is set. The restore
   marker `<db>.restoring` is written, the connection is closed, the live
   file is moved to `<db>.previous`, the new file is moved into place and
   reopened, and a query is run. On success `<db>.previous` and the marker
   are deleted and the queued (not yet uploaded) sync change files are
   discarded; on failure the previous file is moved back and reopened and
   the flag is cleared (see [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md)).
7. The temporary plain file is always deleted.

If the process dies between the move and the rename, the next open
(`recoverInterruptedRestore`) finishes the swap deterministically: a live
file that opens as a database is kept; otherwise the staged file
(verified before the swap) is moved into place; otherwise the previous
file is moved back. A fresh database is never created while a previous or
staged copy exists. The factory reset deletes every variant.

Selective restore (merge transactions from a date range) decrypts and
validates the same way and reads the plain file directly, without replacing
the live database. It copies row families together (a split parent with
its children, both legs of a transfer; a leg whose other account or leg is
unavailable becomes a normal row), copies missing accounts, categories,
groups and payees, leaves the partner's personal accounts out, and stamps
every inserted row with `updated_at` = now so sync treats them as fresh
edits.
