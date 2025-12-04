import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/pending_sync_changes.dart';

part 'pending_sync_changes_dao.g.dart';

@DriftAccessor(tables: [PendingSyncChanges])
class PendingSyncChangesDao extends DatabaseAccessor<AppDatabase>
    with _$PendingSyncChangesDaoMixin {
  PendingSyncChangesDao(super.db);

  Future<List<PendingSyncChange>> getPendingChanges({int limit = 100}) {
    return (select(pendingSyncChanges)
          ..orderBy([(t) => OrderingTerm(expression: t.id)])
          ..limit(limit))
        .get();
  }

  Future<void> deleteChange(int id) {
    return (delete(pendingSyncChanges)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteChanges(List<int> ids) {
    return (delete(pendingSyncChanges)..where((t) => t.id.isIn(ids))).go();
  }
}
