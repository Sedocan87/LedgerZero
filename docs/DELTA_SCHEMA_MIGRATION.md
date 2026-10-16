# Sync and Schema Changes

Every change file and snapshot header carries the writer's
`AppDatabase.schemaVersion` (`schema`). Sync format v2 starts with schema
v17. Implementation: `SyncFileCodec.decode(maxSchemaVersion: …)` and
`SyncEngine._applyChangeFile`.

## Newer file, older app

If `schema` is higher than the app's schema version, the file is
authenticated but **not applied**. It is recorded in `sync_quarantine` with
reason `newer_schema` (not counted as a failure), that device's later files
wait, other devices keep syncing, and Sync settings tells the user to update
the app ("Another device uses a newer version of LedgerZero. Update the app
to sync its changes."). After the update the file is applied on the next run. This prevents
an old app from silently dropping new columns.

## Older file, newer app

Rows are applied with the columns they contain:

* a column the file does not have keeps the local value on update and its
  default on insert;
* an unknown column (impossible for files at or below the app's schema)
  makes the file fail and be quarantined.

## Checklist for a schema change

1. Write the drift migration and bump `AppDatabase.currentSchemaVersion`;
   export the schema (`dart run drift_dev schema dump …`) and add a
   migration test.
2. New synced table: add it to `AppDatabase.syncedTables` and to
   `SyncSchema.dependencyOrder` (parents first; the test in
   `test/services/sync/sync_format_test.dart` checks the order against the
   foreign keys) and give it `id` and `updated_at` columns. The v17 step
   shows how the triggers are recreated.
3. Renamed or removed synced column, or changed meaning of a value: files
   of older schemas need a mapping before they are applied (add it in
   `ChangeApplier` keyed on the file's schema version) or the format version
   must be raised.
4. Run the multi-device simulation (`test/services/sync/sync_simulation_test.dart`).
