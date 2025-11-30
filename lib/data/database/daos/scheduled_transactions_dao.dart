import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/scheduled_transactions.dart';

part 'scheduled_transactions_dao.g.dart';

@DriftAccessor(tables: [ScheduledTransactions])
class ScheduledTransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduledTransactionsDaoMixin {
  ScheduledTransactionsDao(super.db);
}
