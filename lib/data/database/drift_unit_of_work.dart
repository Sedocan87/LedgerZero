import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';

/// [UnitOfWork] backed by a drift transaction on [AppDatabase].
///
/// Drift runs every query issued inside the transaction callback (also from
/// DAOs and repositories of the same database) inside that transaction.
/// Nested `transaction` calls create savepoints.
class DriftUnitOfWork implements UnitOfWork {
  DriftUnitOfWork(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() action) => _db.transaction(action);
}
