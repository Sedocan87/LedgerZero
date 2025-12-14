import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/payees_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';

class PayeeRepositoryImpl implements PayeeRepository {
  final PayeesDao _payeesDao;

  PayeeRepositoryImpl(this._payeesDao);

  @override
  Future<List<Payee>> getAllPayees() async {
    try {
      Logger.debug('Fetching all payees');
      final payees = await _payeesDao.getAllPayees();
      Logger.debug('Fetched ${payees.length} payees');
      return payees.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch payees', e, stackTrace);
      throw DatabaseException('Failed to fetch payees', e);
    }
  }

  @override
  Future<Payee?> getPayeeById(String id) async {
    try {
      Logger.debug('Fetching payee with id: $id');
      final payee = await _payeesDao.getPayeeById(id);
      Logger.debug('Payee found: ${payee != null}');
      return payee == null ? null : _mapToDomain(payee);
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch payee $id', e, stackTrace);
      throw DatabaseException('Failed to fetch payee $id', e);
    }
  }

  @override
  Future<void> createPayee(Payee payee) async {
    try {
      Logger.debug('Creating payee: ${payee.name}');
      await _payeesDao.insertPayee(_mapToCompanion(payee));
      Logger.info('Payee created successfully: ${payee.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create payee ${payee.id}', e, stackTrace);
      throw DatabaseException('Failed to create payee ${payee.id}', e);
    }
  }

  @override
  Future<void> updatePayee(Payee payee) async {
    try {
      Logger.debug('Updating payee: ${payee.id}');
      await _payeesDao.updatePayee(_mapToCompanion(payee));
      Logger.info('Payee updated successfully: ${payee.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update payee ${payee.id}', e, stackTrace);
      throw DatabaseException('Failed to update payee ${payee.id}', e);
    }
  }

  @override
  Future<void> deletePayee(String id) async {
    try {
      Logger.debug('Deleting payee: $id');
      await _payeesDao.deletePayee(id);
      Logger.info('Payee deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete payee $id', e, stackTrace);
      throw DatabaseException('Failed to delete payee $id', e);
    }
  }

  @override
  Stream<List<Payee>> watchAllPayees() {
    return _payeesDao
        .watchAllPayees()
        .map((payees) {
          return payees.map(_mapToDomain).toList();
        })
        .handleError((error, stackTrace) {
          Logger.error('Error in watchAllPayees stream', error, stackTrace);
          throw DatabaseException('Error watching payees', error);
        });
  }

  @override
  Stream<List<Payee>> watchSuggestedPayees() {
    return _payeesDao
        .watchSuggestedPayees()
        .map((payees) {
          return payees.map(_mapToDomain).toList();
        })
        .handleError((error, stackTrace) {
          Logger.error(
            'Error in watchSuggestedPayees stream',
            error,
            stackTrace,
          );
          throw DatabaseException('Error watching suggested payees', error);
        });
  }

  Payee _mapToDomain(db.Payee p) {
    return Payee(
      id: p.id,
      name: p.name,
      autoCategoryId: p.autoCategoryId,
      defaultAccountId: p.defaultAccountId,
      createdAt: p.createdAt,
      icon: p.icon,
      color: p.color,
      notes: p.notes,
      isFavorite: p.isFavorite,
    );
  }

  db.PayeesCompanion _mapToCompanion(Payee p) {
    return db.PayeesCompanion(
      id: Value(p.id),
      name: Value(p.name),
      autoCategoryId: Value(p.autoCategoryId),
      defaultAccountId: Value(p.defaultAccountId),
      createdAt: Value(p.createdAt),
      icon: Value(p.icon),
      color: Value(p.color),
      notes: Value(p.notes),
      isFavorite: Value(p.isFavorite),
    );
  }
}
