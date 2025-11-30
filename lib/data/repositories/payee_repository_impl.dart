import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/daos/payees_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';

class PayeeRepositoryImpl implements PayeeRepository {
  final PayeesDao _payeesDao;

  PayeeRepositoryImpl(this._payeesDao);

  @override
  Future<List<Payee>> getAllPayees() async {
    final payees = await _payeesDao.getAllPayees();
    return payees.map(_mapToDomain).toList();
  }

  @override
  Future<Payee?> getPayeeById(String id) async {
    final payee = await _payeesDao.getPayeeById(id);
    return payee == null ? null : _mapToDomain(payee);
  }

  @override
  Future<void> createPayee(Payee payee) async {
    await _payeesDao.insertPayee(_mapToCompanion(payee));
  }

  @override
  Future<void> updatePayee(Payee payee) async {
    await _payeesDao.updatePayee(_mapToCompanion(payee));
  }

  @override
  Future<void> deletePayee(String id) async {
    await _payeesDao.deletePayee(id);
  }

  @override
  Stream<List<Payee>> watchAllPayees() {
    return _payeesDao.watchAllPayees().map(
          (payees) => payees.map(_mapToDomain).toList(),
        );
  }

  Payee _mapToDomain(db.Payee p) {
    return Payee(
      id: p.id,
      name: p.name,
      autoCategoryId: p.autoCategoryId,
      createdAt: p.createdAt,
    );
  }

  db.PayeesCompanion _mapToCompanion(Payee p) {
    return db.PayeesCompanion(
      id: Value(p.id),
      name: Value(p.name),
      autoCategoryId: Value(p.autoCategoryId),
      createdAt: Value(p.createdAt),
    );
  }
}
