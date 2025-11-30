import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/payees.dart';

part 'payees_dao.g.dart';

@DriftAccessor(tables: [Payees])
class PayeesDao extends DatabaseAccessor<AppDatabase> with _$PayeesDaoMixin {
  PayeesDao(super.db);

  Future<List<Payee>> getAllPayees() => select(payees).get();

  Future<Payee?> getPayeeById(String id) =>
      (select(payees)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertPayee(PayeesCompanion payee) => into(payees).insert(payee);

  Future<bool> updatePayee(PayeesCompanion payee) =>
      update(payees).replace(payee);

  Future<int> deletePayee(String id) =>
      (delete(payees)..where((tbl) => tbl.id.equals(id))).go();

  Stream<List<Payee>> watchAllPayees() => select(payees).watch();
}
