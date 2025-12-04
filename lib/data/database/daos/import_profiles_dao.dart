import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/import_profiles.dart';
import 'package:ledger_zero/domain/entities/import_profile.dart' as domain;

part 'import_profiles_dao.g.dart';

@DriftAccessor(tables: [ImportProfiles])
class ImportProfilesDao extends DatabaseAccessor<AppDatabase> with _$ImportProfilesDaoMixin {
  ImportProfilesDao(super.db);

  Future<List<domain.ImportProfile>> getAllProfiles() {
    return select(importProfiles).map(_toDomain).get();
  }

  Stream<List<domain.ImportProfile>> watchAllProfiles() {
    return select(importProfiles).map(_toDomain).watch();
  }

  Future<domain.ImportProfile?> getProfileById(String id) {
    return (select(importProfiles)..where((t) => t.id.equals(id)))
        .map(_toDomain)
        .getSingleOrNull();
  }

  Future<void> createProfile(domain.ImportProfile profile) {
    return into(importProfiles).insert(_toCompanion(profile));
  }

  Future<void> updateProfile(domain.ImportProfile profile) {
    return update(importProfiles).replace(_toCompanion(profile));
  }

  Future<void> deleteProfile(String id) {
    return (delete(importProfiles)..where((t) => t.id.equals(id))).go();
  }

  domain.ImportProfile _toDomain(ImportProfile data) {
    return domain.ImportProfile(
      id: data.id,
      name: data.name,
      dateFormat: data.dateFormat,
      decimalSeparator: data.decimalSeparator,
      outflowIsNegative: data.outflowIsNegative,
      dateColumn: data.dateColumn,
      amountColumn: data.amountColumn,
      payeeColumn: data.payeeColumn,
      memoColumn: data.memoColumn,
      categoryColumn: data.categoryColumn,
      createdAt: DateTime.parse(data.createdAt),
    );
  }

  ImportProfilesCompanion _toCompanion(domain.ImportProfile profile) {
    return ImportProfilesCompanion(
      id: Value(profile.id),
      name: Value(profile.name),
      dateFormat: Value(profile.dateFormat),
      decimalSeparator: Value(profile.decimalSeparator),
      outflowIsNegative: Value(profile.outflowIsNegative),
      dateColumn: Value(profile.dateColumn),
      amountColumn: Value(profile.amountColumn),
      payeeColumn: Value(profile.payeeColumn),
      memoColumn: Value(profile.memoColumn),
      categoryColumn: Value(profile.categoryColumn),
      createdAt: Value(profile.createdAt.toIso8601String()),
    );
  }
}
