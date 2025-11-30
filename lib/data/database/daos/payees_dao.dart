import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';

part 'payees_dao.g.dart';

@DriftAccessor(tables: [Payees])
class PayeesDao extends DatabaseAccessor<AppDatabase> with _$PayeesDaoMixin {
  PayeesDao(super.db);
}
