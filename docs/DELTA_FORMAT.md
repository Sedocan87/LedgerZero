# Sync File Format (v2)

Implementation: `lib/services/sync/format/` (`sync_file_name.dart`,
`sync_file_codec.dart`, `sync_change.dart`, `sync_manifest.dart`).
Architecture: [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md).

## Files in the sync folder

| Name | Content |
| --- | --- |
| `ledgerzero-sync-manifest.json` | KDF parameters, salt, sync id, key check (not secret) |
| `<deviceId>_<seq>.lzsync` | encrypted change file |
| `<deviceId>_<seq>.lzsnap` | encrypted snapshot |

`deviceId` is a lower-case v4 UUID, `seq` a 12-digit zero-padded decimal
(1 .. 999999999999), so names sort numerically. Names must match

```
^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_[0-9]{12}\.(lzsync|lzsnap)$
```

and equal their own basename; everything else is ignored. Files ending in
`.json.gz` are sync format v1 and are ignored (Sync settings mentions them).

## Manifest

```json
{
  "format": "ledgerzero-sync",
  "version": 2,
  "syncId": "<random v4 UUID>",
  "kdf": {"alg": "argon2id", "v": 19, "m": 47104, "t": 2, "p": 1, "salt": "<base64>"},
  "keyCheck": {"nonce": "<base64, 12 bytes>", "ciphertext": "<base64>"},
  "createdAt": "2026-10-16T08:00:00.000Z"
}
```

* master = Argon2id(passphrase, kdf) (32 bytes);
* sync key = HKDF-SHA256(ikm = master, salt = UTF-8(syncId),
  info = `ledgerzero-sync-v2 file key`);
* keyCheck = AES-256-GCM(sync key, nonce, `ledgerzero-sync-key-check-v2`,
  aad = `ledgerzero-sync-manifest-v2|<syncId>|` + canonical KDF JSON).

A wrong passphrase, or changed KDF parameters or sync id, fail the check.

## Change file / snapshot container

```
"LZS2" | u32 big-endian header length | header JSON (UTF-8)
       | nonce (12 bytes) | AES-256-GCM ciphertext + 16-byte tag
```

Associated data = magic + length + header bytes. Plaintext =
gzip(UTF-8 JSON body). There is no separate checksum: the GCM tag
authenticates header and body.

### Header

```json
{
  "format": 2,
  "kind": "changes",            // or "snapshot"
  "device": "<deviceId>",
  "seq": 42,
  "schema": 17,                 // AppDatabase.schemaVersion of the writer
  "count": 3,                   // number of changes in the body
  "maxVersion": 1792137600000000,
  "vector": {"<deviceId>": 17}, // changes: writer's high-water marks;
                                // snapshot: sequences it includes
  "createdAt": "2026-10-16T08:00:00.000Z"
}
```

The header must match the file name (device, sequence, kind); otherwise the
file is quarantined.

### Body

```json
{"changes": [
  {"t": "transactions", "id": "…", "op": "u", "v": 1792137600000000,
   "dev": "<deviceId>", "row": {"id": "…", "account_id": "…", "amount": -1999, …}},
  {"t": "payees", "id": "…", "op": "d", "v": 1792137600123000, "dev": "<deviceId>"}
]}
```

* `op`: `u` upsert (full row: every column, raw SQL values — text, integer,
  real or null; money is integer minor units, DateTimes UTC ISO-8601 text) or
  `d` delete (tombstone, no row).
* `v`: conflict version in microseconds since the epoch, UTC — the row's
  `updated_at` for upserts, the delete time for tombstones.
* `dev`: the device that wrote this version (tie-break and conflict
  detection).

Columns come from drift's table definitions (`SyncSchema`), so every column
of every synced table round-trips.
