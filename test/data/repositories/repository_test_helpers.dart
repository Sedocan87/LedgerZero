import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AccountsDao, TransactionsDao, ScheduledTransactionsDao])
void main() {}
