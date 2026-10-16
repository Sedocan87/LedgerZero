// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_dao.dart';

// ignore_for_file: type=lint
mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncDeviceProgressTable get syncDeviceProgress =>
      attachedDatabase.syncDeviceProgress;
  $SyncKvTable get syncKv => attachedDatabase.syncKv;
  $SyncRowVersionsTable get syncRowVersions => attachedDatabase.syncRowVersions;
  $SyncConflictsTable get syncConflicts => attachedDatabase.syncConflicts;
  $SyncQuarantineTable get syncQuarantine => attachedDatabase.syncQuarantine;
  $PendingSyncChangesTable get pendingSyncChanges =>
      attachedDatabase.pendingSyncChanges;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$SyncDeviceProgressTableTableManager get syncDeviceProgress =>
      $$SyncDeviceProgressTableTableManager(
        _db.attachedDatabase,
        _db.syncDeviceProgress,
      );
  $$SyncKvTableTableManager get syncKv =>
      $$SyncKvTableTableManager(_db.attachedDatabase, _db.syncKv);
  $$SyncRowVersionsTableTableManager get syncRowVersions =>
      $$SyncRowVersionsTableTableManager(
        _db.attachedDatabase,
        _db.syncRowVersions,
      );
  $$SyncConflictsTableTableManager get syncConflicts =>
      $$SyncConflictsTableTableManager(_db.attachedDatabase, _db.syncConflicts);
  $$SyncQuarantineTableTableManager get syncQuarantine =>
      $$SyncQuarantineTableTableManager(
        _db.attachedDatabase,
        _db.syncQuarantine,
      );
  $$PendingSyncChangesTableTableManager get pendingSyncChanges =>
      $$PendingSyncChangesTableTableManager(
        _db.attachedDatabase,
        _db.pendingSyncChanges,
      );
}
