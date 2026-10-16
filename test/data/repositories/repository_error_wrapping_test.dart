import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/data/repositories/import_profile_repository_impl.dart';
import 'package:ledger_zero/data/repositories/parsing_history_repository_impl.dart';
import 'package:ledger_zero/data/repositories/rule_repository_impl.dart';
import 'package:ledger_zero/domain/entities/import_profile.dart';

import '../../helpers/test_database.dart';

/// Database failures surface as [DatabaseException] carrying the original
/// error (REPOSITORY_PATTERN.md), for every repository.
void main() {
  late TestDatabase t;

  setUp(() async {
    t = TestDatabase();
    // Drop the tables behind the repositories so every query fails.
    for (final table in ['import_profiles', 'parsing_history', 'rules']) {
      await t.db.customStatement('DROP TABLE $table');
    }
  });
  tearDown(() => t.close());

  final wrapsCause = isA<DatabaseException>().having(
    (e) => e.originalError,
    'originalError',
    isNotNull,
  );

  test('ImportProfileRepositoryImpl', () async {
    final repo = ImportProfileRepositoryImpl(t.db);
    await expectLater(repo.getAllProfiles(), throwsA(wrapsCause));
    await expectLater(repo.getProfileById('x'), throwsA(wrapsCause));
    await expectLater(repo.deleteProfile('x'), throwsA(wrapsCause));
    await expectLater(
      repo.createProfile(
        ImportProfile(
          id: 'p',
          name: 'Bank',
          dateFormat: 'yyyy-MM-dd',
          decimalSeparator: '.',
          outflowIsNegative: true,
          createdAt: DateTime.utc(2024),
        ),
      ),
      throwsA(wrapsCause),
    );
  });

  test('ParsingHistoryRepositoryImpl', () async {
    final repo = ParsingHistoryRepositoryImpl(t.db.parsingHistoryDao);
    await expectLater(repo.getHistory('x'), throwsA(wrapsCause));
    await expectLater(repo.addHistory('x', null, null), throwsA(wrapsCause));
  });

  test('RuleRepositoryImpl', () async {
    final repo = RuleRepositoryImpl(t.db.rulesDao);
    await expectLater(repo.getRules(), throwsA(wrapsCause));
    await expectLater(repo.getRule('x'), throwsA(wrapsCause));
    await expectLater(repo.deleteRule('x'), throwsA(wrapsCause));
  });
}
