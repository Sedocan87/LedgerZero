# Sync Architecture (format v2)

LedgerZero is local-first: every change is committed to the encrypted local
database, and devices exchange encrypted change files through a cloud folder
(Google Drive `LedgerZero/Sync`). There is no server; the cloud only stores
opaque files.

Code: `lib/services/sync/` (engine, generator, applier, format, transports),
`lib/presentation/providers/sync/` (controller, state),
`lib/presentation/screens/settings/sync_settings_screen.dart` (UI).
Tests: `test/services/sync/` (multi-device simulation, format, transports),
`test/presentation/providers/sync_controller_lifecycle_test.dart`.

## 1. Change capture

SQLite triggers on every synced table (`AppDatabase.syncedTables`: accounts,
categories, category_groups, transactions, payees, budgets,
scheduled_transactions, budget_templates, report_notes, import_profiles,
rules) write each insert/update/delete into `pending_sync_changes`
(table, row id, action, millisecond `changed_at`, and for deletes the deleted
row's `updated_at`).

* `updated_at` is the **conflict timestamp** of a row. When a write leaves it
  unset (insert) or unchanged (update), the trigger sets it to the current
  UTC time, so every local edit carries its edit time.
* The triggers do nothing while a change file is being applied: the applier
  inserts a row into `sync_applying` inside its transaction and every
  trigger has `WHEN NOT EXISTS (SELECT 1 FROM sync_applying)`. Replayed rows
  therefore never come back as local changes (echo prevention), and a crash
  cannot leave the flag set (it is rolled back with the transaction).
* While no sync provider is configured, captured changes are discarded:
  connecting a folder uploads every row anyway (see 6).

## 2. Change files

At the start of every sync run the pending changes become **one change
file** (more only if the run has more than 2,000 row changes). Changes are
squashed per row: an upsert carries the full current row, a delete becomes a
tombstone. The file is written atomically to the outbox
(`<documents>/sync/outbox`, temp file + flush + rename) in the same database
transaction that deletes the processed pending rows and advances the
device's sequence; files left over from a transaction that did not commit
are deleted at the next run.

* Name: `<deviceId>_<sequence, 12 digits>.lzsync` (snapshots `.lzsnap`).
  `deviceId` is a random v4 UUID per installation (SharedPreferences
  `sync_device_id`); the sequence is per device, monotonic, stored in the
  encrypted database and never lower than the highest own sequence found in
  the folder (so a restored database cannot reuse a name).
* Every remote name is validated with a strict regex and `basename` checks
  (`SyncFileName.tryParse`) before anything else; anything else is ignored
  and logged. Remote names never become local paths (downloads are kept in
  memory).
* When a run is split into several files, cuts are made only between row
  families (a split parent and its children, the two legs of a transfer);
  upserts go parents-first and deletes children-first, so every file can be
  applied on its own.

Format details: [DELTA_FORMAT.md](DELTA_FORMAT.md).

## 3. Encryption and the sync passphrase

Each file is AES-256-GCM encrypted with the **sync key**. The key is derived
from a user-chosen **sync passphrase** with Argon2id (the same parameters as
the master password, `KdfParams.recommended()`), then HKDF-SHA256 bound to the
folder's random `syncId`. Salt, KDF parameters, `syncId` and a key-check
value (a known constant encrypted with the key) are in
`ledgerzero-sync-manifest.json` in the cloud folder.

* First device: Sync settings asks for a new passphrase (password policy:
  at least 10 characters, not a common password, strength meter) and
  explains that it is needed on every device and cannot be recovered.
* Further devices: the user enters the passphrase; a wrong one fails the
  key check and is rejected.
* The derived key is stored only in the encrypted database (`sync_kv`), never
  in SharedPreferences or files. Each run verifies it against the manifest;
  if the folder was reset (other `syncId`) the key is forgotten and the user
  is asked again.
* The file header (format, kind, device, sequence, schema version, change
  count, newest timestamp, causal vector) is GCM associated data: it is
  readable for scheduling but cannot be altered. Integrity = the GCM tag;
  anyone with folder access but without the passphrase can neither read nor
  inject rows.
* Two devices creating the manifest at the same moment: both re-read the
  folder; the earliest manifest wins and the other device is told to enter
  that passphrase.
* Backups contain the database and therefore the derived sync key (they
  are encrypted with the backup password).

## 4. Receiving

Each run lists **all** files (Drive: every page, 1,000 per page, ordered by
name). Per device,
`sync_device_progress` stores the last applied sequence (high-water mark);
only files above it are downloaded. Files are applied

* per device strictly in sequence order (a missing sequence means "not
  arrived yet": that device waits);
* causally: a file's header carries the sender's high-water marks when it
  was written; it is applied only after this device has applied those files
  (so a transaction never arrives before the payee it uses);
* across devices, among the files that are ready, in order of
  (newest change timestamp, device id).

Each file is applied in one transaction (`ChangeApplier`) with
`PRAGMA defer_foreign_keys = ON` and advances that device's high-water mark
in the same transaction.

## 5. Conflict rule

Per row, the incoming version wins iff its `(updated_at, deviceId)` is
greater than the local version's (newer timestamp; equal timestamps: the
greater device id). The local version is the row's `updated_at` with the
device that wrote it (`sync_row_versions`); a local change that has not been
sent yet competes the same way — it does not win automatically.

* **Deletes** are tombstones with the delete time (never older than the last
  edit they delete). A delete wins over an older update and loses to a newer
  one. Tombstones are kept in `sync_row_versions` (deleted = 1) so a late,
  older update cannot resurrect the row; they are pruned after 180 days.
* **Natural keys**: budgets (category, month) and report notes (date) are
  unique. If an incoming row has the same natural key as a local row with a
  different id, the same rule decides, and only one row is kept. (Budget ids
  are deterministic UUIDv5 values, so this is a safety net.)
* **Conflicts**: when a version written on this device is replaced by a
  remote version that was made without knowing it (the sender had not yet
  applied the file carrying it) and the content differs, the overwritten
  local row is recorded in `sync_conflicts`. Sync settings lists them:
  *Keep mine* re-applies the local snapshot as a new local edit (newer than
  every known version), *Dismiss* removes the entry.
* Seeded default categories use deterministic ids and a fixed timestamp, so
  they are identical on all devices and never conflict.

## 6. Foreign keys

Within a file parents are applied before children (`SyncSchema.dependencyOrder`:
category_groups, accounts, categories, payees, transactions, budgets,
scheduled_transactions, budget_templates, report_notes, import_profiles,
rules; a test checks it against `PRAGMA foreign_key_list`) and FK checks are
deferred to commit. Causal ordering (4) guarantees parents created elsewhere
arrive first. A reference that is still missing at commit means the parent
was deleted on another device while this row was created or edited. Policy
(deterministic, so every device ends in the same state):

* nullable reference (transaction category/payee/transfer account, payee
  defaults, category group, schedule references): set to NULL;
* required reference (transaction account, budget category) and split
  children whose parent transaction is gone: the row is deleted.

## 7. Quarantine

If a file cannot be decrypted, parsed or applied, its transaction is rolled
back and the file is recorded in `sync_quarantine` (file name, error, first
seen, attempts). Its device's high-water mark does not advance, so later
files of that device wait; all other devices keep syncing. The file is
retried automatically with backoff (5 min, 30 min, 3 h, 18 h; after 5
attempts only on request). Sync settings shows "N change files could not be
applied" with *Retry*, *Share diagnostics* (file names and errors only) and
*Skip file* (advances past it; its changes are lost on this device).

A file written by a newer app version (schema version above this app's) is
not applied and not counted as a failure: Sync settings asks the user to
update the app ("… Update the app to sync its changes.") and the file is
retried on every run.

## 8. Snapshots and compaction

A snapshot (`<deviceId>_<seq>.lzsnap`) contains every synced row and
tombstone of the writing device plus the per-device sequences whose effects
it includes. A device writes one when it has written 500 change files since
its last snapshot or the last one is older than 7 days (and it has new
files). It deletes **its own** change files covered by its newest own
snapshot that is older than 30 days, and its older snapshots; other devices'
files are never deleted.

* A new device (no progress for any other device) applies the newest
  snapshot under the normal conflict rule and then the files after the
  snapshot's sequences.
* A device whose next file was compacted away (offline for more than 30
  days) bridges the gap with a snapshot that covers it.

## 9. Restore

A full restore empties `pending_sync_changes`, deletes the outbox and
sets the SharedPreferences flag `sync_rebootstrap_required`. The next run:
forgets all high-water marks, continues its sequence after the highest own
file in the folder, applies the newest snapshot and every later file —
including this device's own files from before the restore — **under the
conflict rule** (restored rows win only where their `updated_at` is newer),
then uploads every local row again (rows only the backup has are shared;
rows that lost are already replaced) and clears the flag.

## 10. Lifecycle

`SyncController` (`syncControllerProvider`) is created when the app starts
and follows `appLockStateProvider`:

* locked: the running sync is cancelled (checked between steps and files),
  timers and subscriptions stop, nothing touches the database;
* unlocked: sync on unlock, on app resume if the last sync is older than 60 s,
  10 s after local changes (debounced, watching the pending count), on the
  periodic timer of the frequency setting (real-time = 5 min) and when
  connectivity returns. With frequency *manual* none of these run; only
  *Sync Now* / pull to refresh on the Home screen. *Wi-Fi only* applies to automatic syncs.
* Every entry point catches its errors (no unhandled futures); retryable
  failures of automatic syncs are retried with backoff (30 s .. 4 min).
* State for the UI: status, last sync, pending changes, conflicts,
  quarantine, newer-schema and old-folder notices, setup state.

## 11. Transports

`SyncTransport`: list all files, download (complete bytes), idempotent upload
by name, delete, dispose.

* Google Drive (`GoogleDriveService`): one cached authenticated client per
  session (closed on sign-out/dispose, recreated once on 401); folder ids
  cached but validated once per session and re-resolved on 404/trash;
  uploads look the name up first, so a retried create never duplicates a
  file; transient errors (408, 429, rate limits, 5xx, network) are retried.

* Local Wi-Fi (`lib/services/sync/lan/`, Settings > Sync > Home Wi-Fi):
  phones on the same network sync without any cloud. See below.

### Local Wi-Fi

Meant for a household sharing one budget (for example a couple's two
phones). The engine is unchanged: it runs against a folder on the phone
(`<documents>/sync/lan`, `LocalSyncFolder`), and the phones copy files
between their folders.

* **Pairing.** "Start on this phone" generates a pair key (32 random bytes)
  and a sync passphrase (26 random Crockford-base32 characters, 130 bits)
  and creates the folder's manifest. "Pair a phone" shows a QR code
  (`lzpair1:` + base64url JSON: pair key, passphrase, device id and name,
  the phone's IPv4 addresses and port), also as text for typing. The other
  phone scans it, stores pair key and passphrase in the KeyStore-protected
  secure storage (`lz_lan_pairing_v1`), fetches the first phone's folder and
  joins it with the passphrase like any further device; its own rows are
  merged by the first sync. The passphrase is never typed or shown as such.
* **Transport.** While the app is in the foreground and paired, each phone
  runs an HTTP server on TCP 47321 (another free port if taken) serving its
  folder: `POST /v1/exchange` (folder states both ways), `GET` and
  `PUT /v1/files/<name>`. Only sync file names are served or accepted;
  bodies are limited to 64 MiB. When the engine lists the folder, the
  transport exchanges with every paired phone that has an address: it
  downloads what it lacks and uploads what the other lacks. Each file the
  engine uploads is also pushed to phones reached in the last 10 minutes.
  Deletions (compaction of a device's own files) are recorded and sent with
  the next exchange, so the other phone deletes its copy instead of copying
  the file back.
* **Authentication.** Every request carries `X-LZ-Auth: v1 <device> <time>
  <nonce> <HMAC-SHA256>` under the pair key (method, path, device, time,
  nonce, body hash); the server rejects anything older than 2 minutes or
  replayed, and signs its response (`X-LZ-Mac`). The files themselves stay
  AES-GCM encrypted with the sync key as on Drive. Phones paired with
  different codes (different manifests) refuse to exchange
  (`pairingMismatch`).
* **Discovery.** UDP broadcast beacons on port 47322 every 15 s, tagged
  with an HMAC under the pair key (others are ignored and cannot redirect
  a phone). A beacon or an incoming exchange updates the peer's address
  and triggers a sync. Where broadcasts are blocked (guest networks, some
  mesh systems) the address from the pairing code and the last known
  address are used.
* **Limits.** Android stops background apps, so the server only runs while
  LedgerZero is open: phones sync when both have the app open on the same
  Wi-Fi (on opening, every 5 minutes with "real-time", after local changes
  and when the other phone appears). Each phone works fully on its own in
  between.

## 12. Old format

Files of sync format v1 (`*.json.gz`, plaintext) are ignored and never
deleted by the app; Sync settings tells the user that an old sync folder was
found and can be removed. The local v1 queue (`<documents>/deltas`) is
removed. No migration exists (v1 was never released).

## What only real accounts can verify

Drive OAuth, quota and rate-limit behaviour, background transfer timing and metadata propagation delays are covered by
fakes in tests and must be checked on devices with real accounts.
