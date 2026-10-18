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
  `sync_device_id`, with a copy in `sync_kv.device_id` that wins when the
  two differ, so lost preferences do not orphan queued files; a restore
  strips the id from the restored database so another phone's backup
  never clones it); the sequence is per device, monotonic, stored in the
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
the backup password, `KdfParams.recommended()`), then HKDF-SHA256 bound to the
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
  that passphrase. Transports never replace an existing manifest (an
  overwritten manifest would orphan every file in the folder).
* Files that do not authenticate under the current key and were written
  before the current manifest (header `createdAt`) are leftovers of an
  earlier sync folder: they are skipped, never block anything, and Sync
  settings lists them ("N files from an old sync folder") with *Remove*
  (deleted from the folder) and *Ignore*.
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
  Because of that, a **re-share** (the full upload after a restore, or
  after reconnecting to the same folder) sends a row older than 180 days
  only if this device's version is newer than the version the folder is
  known to have (`sync_row_versions`); a row that old which the folder
  does not know stays local — it may have been deleted elsewhere long
  enough ago for the tombstone to be gone. Joining a *new* folder shares
  everything. Restoring a backup older than 180 days warns the user.
* **Natural keys**: budgets (category, month) and report notes (date) are
  unique. If an incoming row has the same natural key as a local row with a
  different id, the same rule decides, and only one row is kept. (Budget ids
  are deterministic UUIDv5 values, so this is a safety net.)
* **Conflicts**: when a version written on this device is replaced by a
  remote version that was made without knowing it (the sender had not yet
  applied the file carrying it) and the content differs, the overwritten
  local row is recorded in `sync_conflicts`. Sync settings lists them:
  *Keep mine* re-applies the local snapshot as a new local edit (newer than
  every known version), *Dismiss* removes the entry. Not recorded: a budget
  amount written by the automatic new-month fill (its `updated_at` is the
  first day of its month, 00:00 UTC; see BUDGET_INTERACTIONS.md).
* Seeded default categories use deterministic ids and a fixed timestamp.
  Their names are in the app language, so in a bilingual household the two
  phones seed different names under the same ids. The phone that creates
  the sync folder stamps its untouched seeds with the current time: it
  keeps its language, and the other phone's untouched seeds lose
  deterministically (no conflict entries: nothing the user decided was
  lost). A category renamed on either phone is newer and wins.

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
back and the file is recorded in `sync_quarantine` (file name, reason,
error, first seen, attempts). Its device's high-water mark does not
advance, so later files of that device wait; all other devices keep
syncing. The file is retried automatically with backoff (5 min, 30 min,
3 h, 18 h). Reasons:

* `unreadable`: the file does not authenticate under the sync key (damaged
  or incomplete upload). After the 5th failed attempt it is skipped
  automatically (see below) instead of blocking the device forever.
* `failed`: parse or apply error (most likely a bug); it stays blocked
  until *Retry* or *Skip file*.
* `foreign`: a leftover of an earlier folder (section 3); never blocks.
* `newer_schema`: see below.

Sync settings shows "N change files could not be applied" with *Retry*,
*Share diagnostics* (file names and errors only) and *Skip file*.

**Skipping** a file (by hand, or automatically for an unreadable one)
advances past it and records in `sync_kv` (`needs_snapshot`) that its
device owes this device a snapshot covering the skipped sequence. Every
run first applies, for each such device, its newest snapshot that covers
the sequence (the rows the file carried are in it, under the conflict
rule) and then forgets the entry; if no snapshot covers it, this device
writes a small request file `<device>_req_<me>.lzsreq` (no data,
unauthenticated: a folder member could at most trigger extra snapshots).
A device that finds a request for itself writes a snapshot on its next
run and deletes the request. Skipped changes are therefore delayed, not
lost — unless the sender never comes back.

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

A full restore pauses the sync controller (the running sync is cancelled
and awaited; no run starts until the database is reopened), empties
`pending_sync_changes`, sets the SharedPreferences flag
`sync_rebootstrap_required` *before* the database files are swapped and
deletes the outbox after the swap succeeded (on a rollback the flag is
cleared). The next run: forgets all high-water marks, continues its
sequence after the highest own file in the folder, applies the newest
snapshot and every later file **under the conflict rule** (restored rows
win only where their `updated_at` is newer; this device's own pre-restore
files are covered by the snapshot and skipped like any file at or below
the snapshot's sequences, otherwise re-applied), then re-shares the local
rows under the retention rule of section 5 (rows only the backup has are
shared, old rows the folder does not know stay local; rows that lost are
already replaced) and clears the flag. Restoring a backup that carries
another member id, or that is older than the tombstone retention, needs an
explicit confirmation (see BACKUP_AND_EXPORT.md).

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
  quarantine (failed, old-folder files), newer-schema and old-folder
  notices, clock notices, setup state. The Home sync card shows the
  counts of conflicts, failed files and old-folder files.
* Pause/resume around a restore (section 9).

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
  replayed, and signs its response (`X-LZ-Mac`). A request that is signed
  under the pair key but outside the 2-minute window gets a signed 401
  with the server's time (`X-LZ-Time`): the client reports the clock
  difference (`clockSkew`; the join says "the other phone's clock differs
  by N minutes") instead of "phone not found". The exchange response also
  carries the sender's time, so the skew is logged and shown.
* **Clocks.** The conflict rule depends on the phones' clocks. A change
  file whose newest timestamp lies more than 5 minutes in the future
  shows a notice in Sync settings ("check that its clock is automatic").
  A full hybrid logical clock is out of scope. The files themselves stay
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

## 12. Personal accounts

A personal account (`accounts.owner_id` set, schema v20) belongs to one
household member; see BUDGETING_RULES.md for what users see.

* **Member id.** `sync_kv` key `member_id`: a random UUID created when this
  device's user first makes an account personal. It lives in the database,
  not in SharedPreferences like the device id, so a restored backup keeps
  its accounts personal to the same member. A row whose `owner_id` is
  another value is the partner's account.
* **What syncs.** The account row (name, type, owner, closed, and
  `shared_balance`). The account's transactions and scheduled transactions
  never leave the device: `PersonalRows` leaves them out of change files and
  snapshots. Their captured changes are dropped like the others. Tombstones
  are not filtered (a deleted row's account is unknown; one the partner
  never had changes nothing there).
* **Balance.** Triggers on transactions and accounts keep
  `shared_balance` of this member's personal accounts equal to the computed
  balance. Changing it goes through the accounts sync trigger, so every
  balance change gives the row a new `updated_at` and reaches the partner.
  `AccountsDao.balanceExpression` uses `shared_balance` for the partner's
  accounts and the computed balance for all others. The net worth report
  counts the partner's accounts at that balance over the whole range (they
  have no history here).
* **Read-only.** The repository refuses to update the partner's accounts;
  `TransactionService` refuses to save or delete a transaction whose
  account or transfer account is one (`partnerAccount`); pickers leave
  them out. A transfer from a shared account into a personal one syncs as
  its shared leg only; its `transfer_transaction_id` points at a row the
  partner does not have (it is not a foreign key).
* **Becoming shared.** Setting the owner to shared queues every
  transaction and scheduled transaction of the account
  (`AccountsDao.queueHistoryForSync`); the partner applies them as new
  rows. The opposite is refused by the repository
  (`AccountSharedException`) while the account has an entry in
  `sync_row_versions` *and* a sync folder is still set up (the derived
  key is stored); after Disconnect it is allowed again.
* **Only in this phone's backups.** Personal transactions exist on one
  phone only, so without a backup (Settings > Backup & Export, encrypted
  with a backup password) they are lost with the phone. The Backup screen
  says so and nudges when personal accounts exist and the last backup is
  older than 7 days. The account form's "Personal" help text says the
  same.
* **Restoring another member's backup** swaps identity: the backup's
  `member_id` becomes this phone's, its personal accounts become "mine",
  and the accounts that were mine become the partner's (read-only, their
  transactions gone from this phone). The restore inspects the backup
  first (`RestoreService.prepareRestore`) and asks for an explicit
  confirmation when the backup's member id differs from this phone's and
  this phone has a member id or shows personal accounts.
* **Not covered.** One member with two phones: personal transactions do
  not reach the member's second phone (everyone in the folder can read
  every file, so they are never uploaded at all). Payees created for
  personal transactions sync like all payees.

## 13. Old format

Files of sync format v1 (`*.json.gz`, plaintext) are ignored and never
deleted by the app; Sync settings tells the user that an old sync folder was
found and can be removed. The local v1 queue (`<documents>/deltas`) is
removed. No migration exists (v1 was never released).

## What only real accounts can verify

Drive OAuth, quota and rate-limit behaviour, background transfer timing and metadata propagation delays are covered by
fakes in tests and must be checked on devices with real accounts.
