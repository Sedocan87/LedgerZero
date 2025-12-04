import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/import_profile.dart' as domain;
import 'package:ledger_zero/domain/repositories/import_profile_repository.dart';

class ImportProfileRepositoryImpl implements ImportProfileRepository {
  final AppDatabase _db;

  ImportProfileRepositoryImpl(this._db);

  @override
  Future<List<domain.ImportProfile>> getAllProfiles() {
    return _db.importProfilesDao.getAllProfiles();
  }

  @override
  Future<domain.ImportProfile?> getProfileById(String id) {
    return _db.importProfilesDao.getProfileById(id);
  }

  @override
  Future<void> createProfile(domain.ImportProfile profile) {
    return _db.importProfilesDao.createProfile(profile);
  }

  @override
  Future<void> updateProfile(domain.ImportProfile profile) {
    return _db.importProfilesDao.updateProfile(profile);
  }

  @override
  Future<void> deleteProfile(String id) {
    return _db.importProfilesDao.deleteProfile(id);
  }

  @override
  Stream<List<domain.ImportProfile>> watchAllProfiles() {
    return _db.importProfilesDao.watchAllProfiles();
  }
}
