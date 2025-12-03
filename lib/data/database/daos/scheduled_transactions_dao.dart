import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/scheduled_transactions.dart';

part 'scheduled_transactions_dao.g.dart';

@DriftAccessor(tables: [ScheduledTransactions])
class ScheduledTransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledTransactionsDaoMixin {
  ScheduledTransactionsDao(super.db);

  Future<List<ScheduledTransaction>> getAllScheduledTransactions() =>
      select(scheduledTransactions).get();

  Stream<List<ScheduledTransaction>> watchAllScheduledTransactions() =>
      select(scheduledTransactions).watch();

  Future<ScheduledTransaction?> getScheduledTransactionById(String id) =>
      (select(scheduledTransactions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<ScheduledTransaction>> getDueScheduledTransactions(
          DateTime date) =>
      (select(scheduledTransactions)
            ..where((t) => t.nextDate.isSmallerOrEqualValue(date)))
          .get();

  Future<int> insertScheduledTransaction(ScheduledTransactionsCompanion entry) =>
      into(scheduledTransactions).insert(entry);

  Future<bool> updateScheduledTransaction(ScheduledTransactionsCompanion entry) =>
      update(scheduledTransactions).replace(entry);

  Future<int> deleteScheduledTransaction(String id) =>
      (delete(scheduledTransactions)..where((t) => t.id.equals(id))).go();
}
