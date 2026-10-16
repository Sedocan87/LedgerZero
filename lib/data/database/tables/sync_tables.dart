import 'package:drift/drift.dart';

// Local sync bookkeeping (schema v17). None of these tables is synced; they
// describe this device's view of the shared sync folder. See
// docs/SYNC_ARCHITECTURE.md.

/// Per remote device: the highest change-file sequence applied here (the
/// "high-water mark"). Files with a sequence at or below it are never
/// downloaded again.
class SyncDeviceProgress extends Table {
  TextColumn get deviceId => text()();
  IntColumn get lastSequence => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {deviceId};
}

/// Small key-value store for sync state that must live in the encrypted
/// database: the derived sync key, the sync folder id (`sync_id`), this
/// device's last file sequence, snapshot bookkeeping, flags.
class SyncKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The version of every synced row this device knows about: its conflict
/// timestamp (`updated_at` in microseconds since the epoch, UTC), the device
/// that wrote that version, and whether the version is a delete (a
/// tombstone). Tombstones keep a late, older update from resurrecting a
/// deleted row; they are pruned after 180 days.
@TableIndex(
  name: 'idx_sync_row_versions_deleted',
  columns: {#deleted, #version},
)
class SyncRowVersions extends Table {
  TextColumn get syncTable => text()();
  TextColumn get rowId => text()();
  IntColumn get version => integer()();
  TextColumn get deviceId => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// For versions written on this device: the sequence of the change file
  /// that carried it. Used to tell concurrent from sequential edits.
  IntColumn get sequence => integer().nullable()();

  @override
  Set<Column> get primaryKey => {syncTable, rowId};
}

/// A local edit that lost against a newer edit from another device. Shown
/// in Sync settings ("keep mine" / "dismiss").
class SyncConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get syncTable => text()();
  TextColumn get rowId => text()();

  /// JSON of the local row that was overwritten; null if it was a delete.
  TextColumn get localSnapshot => text().nullable()();

  /// JSON of the winning remote row; null if the remote change was a delete.
  TextColumn get remoteSnapshot => text().nullable()();
  TextColumn get remoteDeviceId => text()();
  DateTimeColumn get resolvedAt => dateTime()();
}

/// Change files that could not be applied (or are deferred because they
/// come from a newer app version). A quarantined file blocks only its own
/// device's later files.
class SyncQuarantine extends Table {
  TextColumn get filename => text()();
  TextColumn get deviceId => text()();
  IntColumn get sequence => integer()();

  /// `failed` (decrypt/parse/apply error) or `newer_schema`.
  TextColumn get reason => text()();
  TextColumn get error => text()();
  IntColumn get attempts => integer().withDefault(const Constant(1))();
  DateTimeColumn get firstSeen => dateTime()();
  DateTimeColumn get lastAttempt => dateTime()();
  DateTimeColumn get nextAttempt => dateTime()();

  @override
  Set<Column> get primaryKey => {filename};
}

/// Holds one row while a change file is being applied. The sync triggers'
/// WHEN clause checks it, so replayed writes are not captured as local
/// changes (echo prevention). It is written inside the apply transaction
/// and therefore never survives a crash.
class SyncApplying extends Table {
  IntColumn get id => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
