import 'package:intl/intl.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/extensions/scheduled_transaction_extensions.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/transaction_service_types.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

/// Materialises due occurrences of scheduled transactions.
///
/// Catch-up is idempotent and atomic per schedule: all due occurrences of a
/// schedule are inserted and the schedule is advanced in one unit of work,
/// and each occurrence has the deterministic id
/// [DeterministicId.scheduledOccurrence] and is inserted with
/// insert-or-ignore. A crash, a second run or a second device therefore
/// never duplicates an occurrence (and an occurrence the user deleted is
/// not resurrected).
/// Title and body of a reminder. [amountText] is null unless the user opted
/// in to amounts in notifications.
typedef ScheduledReminderText =
    ({String title, String body}) Function(String? amountText);

class ScheduledTransactionService {
  final ScheduledTransactionRepository _scheduledTransactionRepository;
  final TransactionRepository _transactionRepository;
  final NotificationService _notificationService;
  final UnitOfWork _unitOfWork;
  final RuleMatchingService? _ruleMatchingService;
  final ScheduledReminderText? _reminderText;
  final bool Function() _showAmounts;
  final bool Function() _remindersEnabled;

  /// Formats a reminder amount (minor units) in the app's currency and
  /// locale; the default is a plain number.
  final String Function(int minor)? _formatAmount;

  /// Localised memo for generated occurrences without memo and payee (the
  /// default of [processDueTransactions]'s `fallbackMemo`).
  final String Function()? _defaultMemo;

  ScheduledTransactionService(
    this._scheduledTransactionRepository,
    this._transactionRepository,
    this._notificationService, {
    required this._unitOfWork,
    this._ruleMatchingService,
    this._reminderText,
    bool Function()? showAmountsInNotifications,
    bool Function()? remindersEnabled,
    this._formatAmount,
    this._defaultMemo,
  }) : _showAmounts = showAmountsInNotifications ?? _never,
       _remindersEnabled = remindersEnabled ?? _always;

  static bool _never() => false;
  static bool _always() => true;

  /// Notification id of the reminder for [scheduledId] (stable across runs
  /// and SDK versions).
  static int reminderId(String scheduledId) =>
      NotificationIds.scheduledReminder(scheduledId);

  /// Rejects a schedule that would materialise transactions without an
  /// amount: like [TransactionService], a zero (or missing) amount is a
  /// [ValidationException] with [TransactionValidationError.zeroAmount].
  static void validate(ScheduledTransaction schedule) {
    final amount = schedule.amount;
    if (amount == null || amount == 0) {
      throw ValidationException(
        'Scheduled transaction amount cannot be zero',
        TransactionValidationError.zeroAmount,
      );
    }
  }

  /// Validates and stores [schedule] (created when [isNew], otherwise
  /// updated), books its occurrences that are already due (e.g. a salary
  /// whose next date is today) and schedules its reminder.
  Future<void> saveScheduledTransaction(
    ScheduledTransaction schedule, {
    required bool isNew,
  }) async {
    validate(schedule);
    if (isNew) {
      await _scheduledTransactionRepository.createScheduledTransaction(
        schedule,
      );
    } else {
      await _scheduledTransactionRepository.updateScheduledTransaction(
        schedule,
      );
    }
    await processDueTransactions();
    // Catching up may have advanced the schedule.
    final stored = await _scheduledTransactionRepository
        .getScheduledTransactionById(schedule.id);
    await _syncReminder(stored ?? schedule);
  }

  /// Skips the next occurrence of [scheduledId] (same advance step as
  /// catch-up) and moves its reminder to the new next occurrence, or
  /// cancels it when skipping finished the schedule.
  Future<void> skipOccurrence(String scheduledId) async {
    await _scheduledTransactionRepository.skipScheduledTransaction(scheduledId);
    final updated = await _scheduledTransactionRepository
        .getScheduledTransactionById(scheduledId);
    if (updated == null) {
      await _cancelReminder(scheduledId);
      return;
    }
    await _syncReminder(updated);
  }

  /// Reminder bookkeeping never fails a save or skip.
  Future<void> _syncReminder(ScheduledTransaction schedule) async {
    try {
      if (schedule.nextDate == null) {
        await _notificationService.cancelNotification(reminderId(schedule.id));
      } else {
        // Replaces the pending reminder (same id) with the new date.
        await _notificationService.cancelNotification(reminderId(schedule.id));
        await scheduleNotification(schedule);
      }
    } catch (e, stack) {
      Logger.error('Updating the reminder of ${schedule.id} failed', e, stack);
    }
  }

  Future<void> _cancelReminder(String scheduledId) async {
    try {
      await _notificationService.cancelNotification(reminderId(scheduledId));
    } catch (e, stack) {
      Logger.error('Cancelling the reminder of $scheduledId failed', e, stack);
    }
  }

  /// Creates the transactions of all occurrences due on or before [today]
  /// (default: the user's current calendar day) and advances the schedules.
  ///
  /// The generated transaction's memo is the schedule's memo; the user's
  /// rules are applied in [RuleApplyMode.automatic]. If the result has
  /// neither memo nor payee, [fallbackMemo] (a localised "Scheduled
  /// transaction") is used.
  ///
  /// A schedule that fails is rolled back and logged; the others are still
  /// processed. Returns the number of newly created transactions.
  Future<int> processDueTransactions({
    String? fallbackMemo,
    DateTime? today,
  }) async {
    Logger.info('Processing due scheduled transactions...');
    fallbackMemo ??= _defaultMemo?.call();
    var processedCount = 0;
    try {
      // Scheduled dates are calendar days stored as UTC midnight.
      final day = today == null
          ? CalendarDate.today()
          : CalendarDate.normalize(today);

      final dueScheduled = await _scheduledTransactionRepository
          .getDueScheduledTransactions(day);
      if (dueScheduled.isEmpty) {
        return 0;
      }
      final rules = await _loadRules();

      for (final scheduled in dueScheduled) {
        try {
          final result = await _unitOfWork.run(
            () => _catchUp(scheduled.id, day, rules, fallbackMemo),
          );
          if (result == null) {
            continue;
          }
          processedCount += result.created;
          final updated = result.schedule;
          if (updated.nextDate != null) {
            await scheduleNotification(updated);
          } else {
            await _notificationService.cancelNotification(
              reminderId(updated.id),
            );
          }
        } catch (e, stack) {
          Logger.error(
            'Failed to process scheduled transaction ${scheduled.id}',
            e,
            stack,
          );
        }
      }
      if (processedCount > 0) {
        Logger.info('Processed $processedCount scheduled transactions.');
      }
    } catch (e, stack) {
      Logger.error('Failed to process scheduled transactions', e, stack);
    }
    return processedCount;
  }

  /// Runs inside the unit of work: re-reads the schedule (so a concurrent
  /// run that already advanced it is respected), inserts every due
  /// occurrence and stores the advanced schedule. Returns `null` when there
  /// is nothing to do.
  Future<({ScheduledTransaction schedule, int created})?> _catchUp(
    String scheduledId,
    DateTime today,
    List<Rule> rules,
    String? fallbackMemo,
  ) async {
    final scheduled = await _scheduledTransactionRepository
        .getScheduledTransactionById(scheduledId);
    if (scheduled == null || scheduled.nextDate == null) {
      return null;
    }
    if (scheduled.accountId == null) {
      Logger.warning(
        'Skipping scheduled transaction $scheduledId with missing accountId',
      );
      return (schedule: scheduled, created: 0);
    }

    var current = scheduled;
    var created = 0;
    while (current.nextDate != null &&
        !CalendarDate.normalize(current.nextDate!).isAfter(today)) {
      final occurrence = await _buildOccurrence(current, rules, fallbackMemo);
      if (await _transactionRepository.insertTransactionOrIgnore(occurrence)) {
        created++;
      }
      current = current.advanced();
    }

    if (current != scheduled) {
      await _scheduledTransactionRepository.updateScheduledTransaction(current);
    }
    return (schedule: current, created: created);
  }

  Future<Transaction> _buildOccurrence(
    ScheduledTransaction schedule,
    List<Rule> rules,
    String? fallbackMemo,
  ) async {
    // A schedule without an amount (written before validation existed, or
    // by another device) fails here; the schedule is rolled back and logged.
    validate(schedule);
    final date = CalendarDate.normalize(schedule.nextDate!);
    final now = DateTime.now().toUtc();
    final memo = schedule.memo?.trim();
    var transaction = Transaction(
      id: DeterministicId.scheduledOccurrence(schedule.id, date),
      accountId: schedule.accountId!,
      date: date,
      amount: schedule.amount!,
      payeeId: schedule.payeeId,
      categoryId: schedule.categoryId,
      memo: memo == null || memo.isEmpty ? null : memo,
      cleared: TransactionClearStatus.uncleared,
      approved: schedule.autoApprove,
      createdAt: now,
      updatedAt: now,
    );
    final ruleMatching = _ruleMatchingService;
    if (ruleMatching != null && rules.isNotEmpty) {
      transaction = await ruleMatching.apply(
        transaction,
        rules,
        mode: RuleApplyMode.automatic,
      );
    }
    final hasMemo = transaction.memo != null && transaction.memo!.isNotEmpty;
    if (!hasMemo && transaction.payeeId == null && fallbackMemo != null) {
      transaction = transaction.copyWith(memo: fallbackMemo);
    }
    return transaction;
  }

  Future<List<Rule>> _loadRules() async {
    final ruleMatching = _ruleMatchingService;
    if (ruleMatching == null) {
      return const [];
    }
    try {
      return await ruleMatching.loadActiveRules();
    } catch (e, stack) {
      Logger.error('Failed to load rules for scheduled transactions', e, stack);
      return const [];
    }
  }

  /// Re-schedules (or, with reminders off, cancels) the reminder of every
  /// schedule, e.g. after unlock, so new or edited schedules and a changed
  /// Settings toggle take effect. Never throws.
  Future<void> rescheduleReminders() async {
    try {
      final all = await _scheduledTransactionRepository
          .getAllScheduledTransactions();
      for (final schedule in all) {
        await scheduleNotification(schedule);
      }
    } catch (e, stack) {
      Logger.error('Failed to reschedule reminders', e, stack);
    }
  }

  /// Schedules the reminder for the next occurrence of [transaction] (the
  /// day before at 9:00 local time); cancels it when reminders are off.
  Future<void> scheduleNotification(ScheduledTransaction transaction) async {
    if (!_remindersEnabled()) {
      await _notificationService.cancelNotification(reminderId(transaction.id));
      return;
    }
    if (transaction.nextDate == null) {
      return;
    }

    // Notify 1 day before at 9 AM
    final nextDate = transaction.nextDate!;
    final notificationDate = DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day - 1,
      9,
    );

    if (notificationDate.isBefore(DateTime.now())) {
      return;
    }

    // Lock-screen safe by default: no amount unless the user opted in.
    final amountText = _showAmounts()
        ? (_formatAmount?.call(transaction.amount ?? 0) ??
              MoneyFormatter(
                locale: Intl.getCurrentLocale(),
              ).formatNumber(transaction.amount ?? 0))
        : null;
    final text =
        _reminderText?.call(amountText) ??
        (
          title: 'Upcoming transaction',
          body: amountText == null
              ? 'A scheduled transaction is due tomorrow.'
              : 'A scheduled transaction of $amountText is due tomorrow.',
        );
    await _notificationService.scheduleNotification(
      id: reminderId(transaction.id),
      title: text.title,
      body: text.body,
      scheduledDate: notificationDate,
      payload: ScheduledReminderPayload(transaction.id).encode(),
    );
  }
}
