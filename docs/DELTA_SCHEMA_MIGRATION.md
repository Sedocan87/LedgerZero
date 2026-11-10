# Sync and Schema Changes

Every change file and snapshot header carries a schema number (`schema`).
It is `SyncSchema.syncVersion`: the database schema version at which a
**synced table** last changed (20 today, the same as
`AppDatabase.schemaVersion`). Implementation:
`SyncFileCodec.decode(maxSchemaVersion: …)` and
`SyncEngine._applyChangeFile`.

`syncVersion` is deliberately not the database schema version itself. A
schema change that touches no synced table (a local bookkeeping table, a
new index, a settings table) raises `AppDatabase.currentSchemaVersion` and
leaves `syncVersion` alone, so the two phones of a household keep syncing
while only one of them is updated. Files written before and after this
split carry the same number (20), so nothing changed on the wire.

The test "the synced schema has not changed without a new sync version"
(`test/services/sync/sync_format_test.dart`) fingerprints every column of
every synced table and fails when one changes while `syncVersion` stays.

## Newer file, older app

If `schema` is higher than the app's `syncVersion`, the file is
authenticated but **not applied**. It is recorded in `sync_quarantine` with
reason `newer_schema` (not counted as a failure), that device's later files
wait, other devices keep syncing, and the user is told to update the app:
a notice in Sync settings ("Another device uses a newer version of
LedgerZero. Update the app to sync its changes."), a line on the Home sync
card and a notification (at most every three days; Settings > Notification
Settings > Sync). A snapshot of a newer version (a joining phone, a
snapshot bridge) leaves no quarantine entry but raises the same notice for
as long as runs meet it. After the update the file is applied on the next
run. This prevents an old app from silently dropping new columns.

Sync therefore stalls **in one direction** between the first and the second
phone's update: the updated phone keeps applying the other phone's files;
the other phone's own changes keep uploading; only the newer phone's
changes wait. Nothing is lost.

## Older file, newer app

Rows are applied with the columns they contain:

* a column the file does not have keeps the local value on update and its
  default on insert;
* an unknown column makes the file fail and be quarantined (`failed`),
  which blocks that device until someone taps *Skip file* and a snapshot
  arrives. This is what a renamed or removed synced column would cause for
  every file written before the change.

There is **no mapping step** for files of older schemas: `ChangeApplier`
applies the columns as they are named in the file. Do not plan a change
that needs one (see the rules below).

## Rules for a change to a synced table

1. **Additive only.** New columns, each nullable or with a default (a
   drift `withDefault`/SQL `DEFAULT`, so an insert from an older file gets
   a value). New synced tables are fine.
2. **Never rename or remove a synced column, and never change what a
   stored value means** (unit, enum order, encoding). Old files would fail
   on the updated phone, and old phones would misread new files once they
   update. If it cannot be avoided, add a new column and keep writing the
   old one for at least one release, or raise the file format version
   (`SyncFileHeader.currentFormat`), which is a flag day for the household.
3. **Per-column conflict caveat.** The conflict rule is whole-row
   last-writer-wins. A row edited on the phone that is not updated yet,
   after the updated phone set a new column on it, wins the conflict once
   it is applied, and it carries no value for the new column: on the
   updated phone the column keeps its local value (the applier updates
   only the columns the file has), on the other phone it gets the default
   when that phone updates. The two can end up with different values for
   that row until it is edited again. So for every new synced column
   decide what its default means and make the feature that fills it
   tolerate rows that still have the default (treat it as "not set" and
   let the next edit write it), or backfill it in the migration from data
   both phones already agree on, so both compute the same value.
4. **A migration must not turn into edits.** A migration that rewrites
   synced rows drops the sync triggers before and recreates them after
   (as the v15 and v17 steps do). Otherwise every rewritten row becomes a
   local edit stamped with the time of the migration, is uploaded, and
   beats whatever the other phone changes before it updates.

## Checklist

1. Write the drift migration and bump `AppDatabase.currentSchemaVersion`;
   export the schema (`dart run drift_dev schema dump …`) and add a
   migration test.
2. Synced table changed (the fingerprint test fails): set
   `SyncSchema.syncVersion` to the new database schema version and update
   the fingerprint in the test. Not changed: leave both alone.
3. New synced table: add it to `AppDatabase.syncedTables` and to
   `SyncSchema.dependencyOrder` (parents first; the test in
   `test/services/sync/sync_format_test.dart` checks the order against the
   foreign keys) and give it `id` and `updated_at` columns. The v17 step
   shows how the triggers are recreated.
4. Run the multi-device simulation
   (`test/services/sync/sync_simulation_test.dart`) and add a case in
   which one device writes files of the previous `syncVersion`.
5. Release notes: tell households to update both phones; until then the
   phone that was not updated shows the update notice and does not
   receive the other phone's changes.
