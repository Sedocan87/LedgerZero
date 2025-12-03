import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:uuid/uuid.dart';

class ScheduledTransactionService {
  final ScheduledTransactionRepository _scheduledTransactionRepository;
  final TransactionRepository _transactionRepository;
  final NotificationService _notificationService;
  final Uuid _uuid;

  ScheduledTransactionService(
    this._scheduledTransactionRepository,
    this._transactionRepository,
    this._notificationService,
    this._uuid,
  );

  /// Checks for due scheduled transactions and creates real transactions for them.
  /// Also updates the scheduled transaction's next date.
  Future<void> processDueTransactions() async {
    Logger.info('Processing due scheduled transactions...');
    try {
      final allScheduled = await _scheduledTransactionRepository.getAllScheduledTransactions();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int processedCount = 0;

      for (final scheduled in allScheduled) {
        if (scheduled.nextDate == null) {
          continue;
        }

        var currentScheduled = scheduled;

        // Loop to catch up on missed occurrences
        while (currentScheduled.nextDate != null) {
           final currentNextDate = currentScheduled.nextDate!;
           final currentNextDateDateOnly = DateTime(
             currentNextDate.year,
             currentNextDate.month,
             currentNextDate.day
           );

           if (currentNextDateDateOnly.isAfter(today)) {
             break;
           }

           // Validate required fields
           if (currentScheduled.accountId == null) {
             Logger.warning('Skipping scheduled transaction ${currentScheduled.id} with missing accountId');
             break; // Cannot process this one further
           }

           // Create Transaction
           final newTransaction = Transaction(
             id: _uuid.v4(),
             accountId: currentScheduled.accountId!,
             date: currentNextDate,
             amount: currentScheduled.amount ?? 0.0,
             payeeId: currentScheduled.payeeId,
             categoryId: currentScheduled.categoryId,
             memo: 'Scheduled Transaction', // TODO: Localize?
             cleared: TransactionClearStatus.uncleared,
             approved: currentScheduled.autoApprove,
             createdAt: DateTime.now(),
             updatedAt: DateTime.now(),
           );

           await _transactionRepository.createTransaction(newTransaction);
           processedCount++;

           // Update Scheduled Transaction to next date
           final nextDate = currentScheduled.calculateNextOccurrenceDate();

           int? newOccurrenceCount = currentScheduled.occurrenceCount;
           if (newOccurrenceCount != null) {
               newOccurrenceCount--;
           }

           // Determine if schedule is finished
           bool isFinished = nextDate == null;
           if (newOccurrenceCount != null && newOccurrenceCount <= 0) {
             isFinished = true;
           }

           ScheduledTransaction updated;
           if (isFinished) {
             updated = ScheduledTransaction(
               id: currentScheduled.id,
               accountId: currentScheduled.accountId,
               payeeId: currentScheduled.payeeId,
               categoryId: currentScheduled.categoryId,
               amount: currentScheduled.amount,
               frequency: currentScheduled.frequency,
               interval: currentScheduled.interval,
               occurrenceCount: 0, // Force 0 if it was the cause
               nextDate: null,
               endDate: currentScheduled.endDate,
               autoApprove: currentScheduled.autoApprove,
               createdAt: currentScheduled.createdAt,
             );
           } else {
             updated = currentScheduled.copyWith(
               nextDate: nextDate,
               occurrenceCount: newOccurrenceCount,
             );
           }

           await _scheduledTransactionRepository.updateScheduledTransaction(updated);
           currentScheduled = updated;

           // If finished, break the loop
           if (isFinished) {
             break;
           }
        }

        if (currentScheduled.nextDate != null) {
          await scheduleNotification(currentScheduled);
        } else {
          await _notificationService.cancelNotification(currentScheduled.id.hashCode);
        }
      }
      if (processedCount > 0) {
        Logger.info('Processed $processedCount scheduled transactions.');
      }
    } catch (e, stack) {
      Logger.error('Failed to process scheduled transactions', e, stack);
    }
  }

  Future<void> scheduleNotification(ScheduledTransaction transaction) async {
    if (transaction.nextDate == null) {
      return;
    }

    // Notify 1 day before at 9 AM
    final nextDate = transaction.nextDate!;
    final notificationDate =
        DateTime(nextDate.year, nextDate.month, nextDate.day, 9, 0, 0)
            .subtract(const Duration(days: 1));

    if (notificationDate.isBefore(DateTime.now())) {
      return;
    }

    await _notificationService.scheduleNotification(
      id: transaction.id.hashCode,
      title: 'Upcoming Transaction',
      body:
          'You have a scheduled transaction for ${transaction.amount} due tomorrow.',
      scheduledDate: notificationDate,
    );
  }
}
