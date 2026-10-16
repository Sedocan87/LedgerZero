// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_sync_changes_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingSyncChangesDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingSyncChangesTable get pendingSyncChanges =>
      attachedDatabase.pendingSyncChanges;
  PendingSyncChangesDaoManager get managers =>
      PendingSyncChangesDaoManager(this);
}

class PendingSyncChangesDaoManager {
  final _$PendingSyncChangesDaoMixin _db;
  PendingSyncChangesDaoManager(this._db);
  $$PendingSyncChangesTableTableManager get pendingSyncChanges =>
      $$PendingSyncChangesTableTableManager(
        _db.attachedDatabase,
        _db.pendingSyncChanges,
      );
}
