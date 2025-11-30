import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase> with _$AccountsDaoMixin {
  AccountsDao(super.db);
}
