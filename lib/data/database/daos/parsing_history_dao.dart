import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/parsing_history.dart';

part 'parsing_history_dao.g.dart';

@DriftAccessor(tables: [ParsingHistory])
class ParsingHistoryDao extends DatabaseAccessor<AppDatabase> with _$ParsingHistoryDaoMixin {
  ParsingHistoryDao(super.db);

  Future<void> addHistory(ParsingHistoryCompanion entry) => into(parsingHistory).insert(entry);

  Future<List<ParsingHistoryData>> getHistoryForInput(String input) {
    return (select(parsingHistory)..where((tbl) => tbl.input.equals(input))).get();
  }

  Future<void> deleteHistory(String id) {
    return (delete(parsingHistory)..where((tbl) => tbl.id.equals(id))).go();
  }
}
