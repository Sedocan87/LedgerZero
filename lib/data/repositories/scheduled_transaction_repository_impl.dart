import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';

class ScheduledTransactionRepositoryImpl
    implements ScheduledTransactionRepository {
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
  Future<List<ScheduledTransaction>> getDueScheduledTransactions(
    DateTime date,
  ) async {
    try {
      final rows = await _dao.getDueScheduledTransactions(date);
      return rows.map(_mapToDomain).toList();
    } catch (e, stack) {
      Logger.error('Failed to get due scheduled transactions', e, stack);
      throw DatabaseException('Failed to get due scheduled transactions', e);
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
  Future<void> createScheduledTransaction(
    ScheduledTransaction transaction,
  ) async {
    try {
      await _dao.insertScheduledTransaction(_mapToCompanion(transaction));
    } catch (e, stack) {
      Logger.error('Failed to create scheduled transaction', e, stack);
      throw DatabaseException('Failed to create scheduled transaction', e);
    }
  }

  @override
  Future<void> updateScheduledTransaction(
    ScheduledTransaction transaction,
  ) async {
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
  Future<void> skipScheduledTransaction(String id) async {
    try {
      await _dao.transaction(() async {
        final row = await _dao.getScheduledTransactionById(id);
        if (row == null || row.nextDate == null) {
          return;
        }
        // Same advance step as catch-up processing: skipping the last
        // occurrence finishes the schedule.
        final updated = _mapToDomain(row).advanced();
        await _dao.updateScheduledTransaction(_mapToCompanion(updated));
      });
    } catch (e, stack) {
      Logger.error('Failed to skip scheduled transaction $id', e, stack);
      throw DatabaseException('Failed to skip scheduled transaction $id', e);
    }
  }

  @override
  Stream<List<ScheduledTransaction>> watchAllScheduledTransactions() {
    return _dao.watchAllScheduledTransactions().map(
      (rows) => rows.map(_mapToDomain).toList(),
    );
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
              orElse: () => RecurrenceFrequency.monthly,
            )
          : null,
      interval: row.interval,
      occurrenceCount: row.occurrenceCount,
      nextDate: row.nextDate,
      endDate: row.endDate,
      autoApprove: row.autoApprove,
      createdAt: row.createdAt,
      memo: row.memo,
      anchorDay: row.anchorDay,
    );
  }

  db.ScheduledTransactionsCompanion _mapToCompanion(ScheduledTransaction t) {
    final now = DateTime.now().toUtc();
    return db.ScheduledTransactionsCompanion(
      id: Value(t.id),
      accountId: Value(t.accountId),
      payeeId: Value(t.payeeId),
      categoryId: Value(t.categoryId),
      amount: Value(t.amount),
      frequency: Value(t.frequency?.name),
      interval: Value(t.interval),
      occurrenceCount: Value(t.occurrenceCount),
      nextDate: Value(
        t.nextDate == null ? null : CalendarDate.normalize(t.nextDate!),
      ),
      endDate: Value(
        t.endDate == null ? null : CalendarDate.normalize(t.endDate!),
      ),
      autoApprove: Value(t.autoApprove),
      memo: Value(t.memo),
      anchorDay: Value(t.anchorDay),
      createdAt: Value(t.createdAt?.toUtc() ?? now),
      updatedAt: Value(now),
    );
  }
}
