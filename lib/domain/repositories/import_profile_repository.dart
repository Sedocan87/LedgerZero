import 'package:ledger_zero/domain/entities/import_profile.dart';

abstract class ImportProfileRepository {
  Future<List<ImportProfile>> getAllProfiles();
  Future<ImportProfile?> getProfileById(String id);
  Future<void> createProfile(ImportProfile profile);
  Future<void> updateProfile(ImportProfile profile);
  Future<void> deleteProfile(String id);
  Stream<List<ImportProfile>> watchAllProfiles();
}
