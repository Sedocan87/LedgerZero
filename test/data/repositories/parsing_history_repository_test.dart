import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/repositories/parsing_history_repository_impl.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  test('history for an input is returned most recent first', () async {
    Future<void> add(String id, String createdAt, String categoryId) =>
        t.db.customStatement(
          'INSERT INTO parsing_history (id, input, payee_id, category_id, '
          'created_at) VALUES (?, ?, NULL, ?, ?)',
          [id, 'coffee 3', categoryId, createdAt],
        );
    // Inserted out of order: the newest row is neither first nor last.
    await add('z-old', '2024-01-01T08:00:00.000Z', 'old');
    await add('a-new', '2024-03-01T08:00:00.000Z', 'newest');
    await add('m-mid', '2024-02-01T08:00:00.000Z', 'middle');

    final history = await ParsingHistoryRepositoryImpl(
      t.db.parsingHistoryDao,
    ).getHistory('coffee 3');
    expect(history.map((h) => h['categoryId']), ['newest', 'middle', 'old']);
  });
}
