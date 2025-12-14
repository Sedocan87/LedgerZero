import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/sync_log.dart';

part 'sync_log_dao.g.dart';

@DriftAccessor(tables: [SyncLog])
class SyncLogDao extends DatabaseAccessor<AppDatabase> with _$SyncLogDaoMixin {
  SyncLogDao(super.db);

  Future<int> insertSyncLog(SyncLogCompanion entry) {
    return into(syncLog).insert(entry);
  }

  Future<List<String>> getAllFilenames() {
    final query = selectOnly(syncLog)..addColumns([syncLog.deltaFilename]);
    return query
        .map((row) => row.read(syncLog.deltaFilename))
        .get()
        .then((list) => list.whereType<String>().toList());
  }

  Future<List<SyncLogData>> getLogs() {
    return (select(syncLog)..orderBy([
          (t) => OrderingTerm(expression: t.appliedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }
}
