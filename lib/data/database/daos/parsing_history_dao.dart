import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/parsing_history.dart';

part 'parsing_history_dao.g.dart';

@DriftAccessor(tables: [ParsingHistory])
class ParsingHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$ParsingHistoryDaoMixin {
  ParsingHistoryDao(super.db);

  Future<void> addHistory(ParsingHistoryCompanion entry) =>
      into(parsingHistory).insert(entry);

  /// The history entries for exactly [input], most recent first
  /// (`created_at` is UTC ISO-8601 text, so text order is time order; the
  /// id breaks ties). The quick-add parser uses the first one: the user's
  /// latest correction wins over older ones.
  Future<List<ParsingHistoryData>> getHistoryForInput(String input) {
    return (select(parsingHistory)
          ..where((tbl) => tbl.input.equals(input))
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.createdAt),
            (tbl) => OrderingTerm.desc(tbl.id),
          ]))
        .get();
  }

  Future<void> deleteHistory(String id) {
    return (delete(parsingHistory)..where((tbl) => tbl.id.equals(id))).go();
  }
}
