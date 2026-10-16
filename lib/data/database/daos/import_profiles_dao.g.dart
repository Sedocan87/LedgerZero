// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_profiles_dao.dart';

// ignore_for_file: type=lint
mixin _$ImportProfilesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ImportProfilesTable get importProfiles => attachedDatabase.importProfiles;
  ImportProfilesDaoManager get managers => ImportProfilesDaoManager(this);
}

class ImportProfilesDaoManager {
  final _$ImportProfilesDaoMixin _db;
  ImportProfilesDaoManager(this._db);
  $$ImportProfilesTableTableManager get importProfiles =>
      $$ImportProfilesTableTableManager(
        _db.attachedDatabase,
        _db.importProfiles,
      );
}
