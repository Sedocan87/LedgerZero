import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/import_profile.dart' as domain;
import 'package:ledger_zero/domain/repositories/import_profile_repository.dart';

class ImportProfileRepositoryImpl implements ImportProfileRepository {
  final AppDatabase _db;

  ImportProfileRepositoryImpl(this._db);

  /// Runs [action]; failures are logged and rethrown as
  /// [DatabaseException] (see REPOSITORY_PATTERN.md).
  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, stackTrace) {
      Logger.error(message, e, stackTrace);
      throw DatabaseException(message, e);
    }
  }

  @override
  Future<List<domain.ImportProfile>> getAllProfiles() => _guard(
    'Failed to fetch import profiles',
    _db.importProfilesDao.getAllProfiles,
  );

  @override
  Future<domain.ImportProfile?> getProfileById(String id) => _guard(
    'Failed to fetch import profile $id',
    () => _db.importProfilesDao.getProfileById(id),
  );

  @override
  Future<void> createProfile(domain.ImportProfile profile) => _guard(
    'Failed to create import profile',
    () => _db.importProfilesDao.createProfile(profile),
  );

  @override
  Future<void> updateProfile(domain.ImportProfile profile) => _guard(
    'Failed to update import profile ${profile.id}',
    () => _db.importProfilesDao.updateProfile(profile),
  );

  @override
  Future<void> deleteProfile(String id) => _guard(
    'Failed to delete import profile $id',
    () => _db.importProfilesDao.deleteProfile(id),
  );

  @override
  Stream<List<domain.ImportProfile>> watchAllProfiles() =>
      _db.importProfilesDao.watchAllProfiles();
}
