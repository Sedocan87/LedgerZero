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
  Future<void> skipScheduledTransaction(String id) async {
    try {
      final transaction = await getScheduledTransactionById(id);
      if (transaction == null || transaction.nextDate == null) {
        return;
      }

      final nextDate = transaction.nextDate!;
      final interval = transaction.interval ?? 1;
      final frequency = transaction.frequency ?? RecurrenceFrequency.monthly;

      DateTime newDate;
      switch (frequency) {
        case RecurrenceFrequency.daily:
          newDate = nextDate.add(Duration(days: interval));
          break;
        case RecurrenceFrequency.weekly:
          newDate = nextDate.add(Duration(days: interval * 7));
          break;
        case RecurrenceFrequency.monthly:
          // Add months logic
          if (nextDate.isUtc) {
             newDate = DateTime.utc(
               nextDate.year,
               nextDate.month + interval,
               nextDate.day,
               nextDate.hour,
               nextDate.minute,
             );
          } else {
             newDate = DateTime(
               nextDate.year,
               nextDate.month + interval,
               nextDate.day,
               nextDate.hour,
               nextDate.minute,
             );
          }

          // Handle month overflow (e.g., Jan 31 + 1 month = Feb 31 -> Mar 3)
          // Usually we want to clamp to the last day of the month.
          final expectedMonth = (nextDate.month + interval - 1) % 12 + 1;
          final expectedYear = nextDate.year + (nextDate.month + interval - 1) ~/ 12;

          if (newDate.month != expectedMonth) {
             // We overshot (e.g., Feb 31 -> Mar 3), so go back to last day of previous month
             if (nextDate.isUtc) {
                newDate = DateTime.utc(expectedYear, expectedMonth + 1, 0, nextDate.hour, nextDate.minute);
             } else {
                newDate = DateTime(expectedYear, expectedMonth + 1, 0, nextDate.hour, nextDate.minute);
             }
          }
          break;
        case RecurrenceFrequency.yearly:
           if (nextDate.isUtc) {
              newDate = DateTime.utc(
                nextDate.year + interval,
                nextDate.month,
                nextDate.day,
                nextDate.hour,
                nextDate.minute,
              );
           } else {
              newDate = DateTime(
                nextDate.year + interval,
                nextDate.month,
                nextDate.day,
                nextDate.hour,
                nextDate.minute,
              );
           }
           // Handle leap year (Feb 29 + 1 year -> Feb 29 non-leap = Mar 1).
           if (nextDate.month == 2 && nextDate.day == 29 && newDate.month == 3) {
             if (nextDate.isUtc) {
               newDate = DateTime.utc(newDate.year, 2, 28, newDate.hour, newDate.minute);
             } else {
               newDate = DateTime(newDate.year, 2, 28, newDate.hour, newDate.minute);
             }
           }
          break;
      }

      int? newOccurrenceCount = transaction.occurrenceCount;
      if (newOccurrenceCount != null && newOccurrenceCount > 0) {
        newOccurrenceCount--;
      }

      // Check end date
      if (transaction.endDate != null && newDate.isAfter(transaction.endDate!)) {
         // Stop recurrence?
         // Maybe just update it, let the processing logic handle it, or maybe set nextDate to null?
         // For now just update it.
      }

      final updated = transaction.copyWith(
        nextDate: newDate,
        occurrenceCount: newOccurrenceCount,
      );

      await updateScheduledTransaction(updated);

    } catch (e, stack) {
       Logger.error('Failed to skip scheduled transaction $id', e, stack);
       throw DatabaseException('Failed to skip scheduled transaction $id', e);
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
      interval: row.interval,
      occurrenceCount: row.occurrenceCount,
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
      interval: Value(t.interval),
      occurrenceCount: Value(t.occurrenceCount),
      nextDate: Value(t.nextDate),
      endDate: Value(t.endDate),
      autoApprove: Value(t.autoApprove),
      createdAt: Value(t.createdAt),
    );
  }
}
