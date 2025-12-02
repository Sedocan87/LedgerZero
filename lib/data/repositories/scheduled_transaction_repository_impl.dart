import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';

class ScheduledTransactionRepositoryImpl implements ScheduledTransactionRepository {
  final ScheduledTransactionsDao _dao;

  ScheduledTransactionRepositoryImpl(this._dao);

  @override
  Future<List<ScheduledTransaction>> getAllScheduledTransactions() async {
    try {
      final rows = await _dao.getAllScheduledTransactions();
      return rows.map(_mapToDomain).toList();
    } catch (e, stack) {
      Logger.error('Failed to get scheduled transactions', e, stack);
      throw DatabaseException('Failed to get scheduled transactions', e);
    }
  }

  @override
  Future<ScheduledTransaction?> getScheduledTransactionById(String id) async {
    try {
      final row = await _dao.getScheduledTransactionById(id);
      return row == null ? null : _mapToDomain(row);
    } catch (e, stack) {
       Logger.error('Failed to get scheduled transaction $id', e, stack);
       throw DatabaseException('Failed to get scheduled transaction $id', e);
    }
  }

  @override
  Future<void> createScheduledTransaction(ScheduledTransaction transaction) async {
    try {
      await _dao.insertScheduledTransaction(_mapToCompanion(transaction));
    } catch (e, stack) {
       Logger.error('Failed to create scheduled transaction', e, stack);
       throw DatabaseException('Failed to create scheduled transaction', e);
    }
  }

  @override
  Future<void> updateScheduledTransaction(ScheduledTransaction transaction) async {
    try {
      await _dao.updateScheduledTransaction(_mapToCompanion(transaction));
    } catch (e, stack) {
       Logger.error('Failed to update scheduled transaction', e, stack);
       throw DatabaseException('Failed to update scheduled transaction', e);
    }
  }

  @override
  Future<void> deleteScheduledTransaction(String id) async {
    try {
      await _dao.deleteScheduledTransaction(id);
    } catch (e, stack) {
       Logger.error('Failed to delete scheduled transaction $id', e, stack);
       throw DatabaseException('Failed to delete scheduled transaction $id', e);
    }
  }

  @override
  Stream<List<ScheduledTransaction>> watchAllScheduledTransactions() {
    return _dao.watchAllScheduledTransactions().map((rows) => rows.map(_mapToDomain).toList());
  }

  ScheduledTransaction _mapToDomain(db.ScheduledTransaction row) {
    return ScheduledTransaction(
      id: row.id,
      accountId: row.accountId,
      payeeId: row.payeeId,
      categoryId: row.categoryId,
      amount: row.amount,
      frequency: row.frequency != null
          ? RecurrenceFrequency.values.firstWhere(
              (e) => e.name == row.frequency,
              orElse: () => RecurrenceFrequency.monthly)
          : null,
      nextDate: row.nextDate,
      endDate: row.endDate,
      autoApprove: row.autoApprove,
      createdAt: row.createdAt,
    );
  }

  db.ScheduledTransactionsCompanion _mapToCompanion(ScheduledTransaction t) {
    return db.ScheduledTransactionsCompanion(
      id: Value(t.id),
      accountId: Value(t.accountId),
      payeeId: Value(t.payeeId),
      categoryId: Value(t.categoryId),
      amount: Value(t.amount),
      frequency: Value(t.frequency?.name),
      nextDate: Value(t.nextDate),
      endDate: Value(t.endDate),
      autoApprove: Value(t.autoApprove),
      createdAt: Value(t.createdAt),
    );
  }
}
