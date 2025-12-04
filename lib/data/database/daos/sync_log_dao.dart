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
}
