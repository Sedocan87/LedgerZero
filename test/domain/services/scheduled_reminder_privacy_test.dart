import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';

import '../../helpers/test_database.dart';

class _RecordingNotifications extends Fake implements NotificationService {
  final bodies = <String>[];

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    bodies.add(body);
  }
}

void main() {
  late TestDatabase t;
  late _RecordingNotifications notifications;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  ScheduledTransaction schedule() {
    final now = CalendarDate.today();
    return ScheduledTransaction(
      id: 's1',
      accountId: 'a1',
      amount: -123456,
      frequency: RecurrenceFrequency.monthly,
      nextDate: DateTime.utc(now.year, now.month, now.day + 3),
    );
  }

  ScheduledTransactionService service({required bool showAmounts}) {
    notifications = _RecordingNotifications();
    return ScheduledTransactionService(
      t.scheduledTransactions,
      t.transactions,
      notifications,
      unitOfWork: t.unitOfWork,
      showAmountsInNotifications: () => showAmounts,
      reminderText: (amount) => (
        title: 'Upcoming',
        body: amount == null ? 'A payment is due.' : 'Due: $amount',
      ),
    );
  }

  test('reminders do not show the amount by default', () async {
    await service(showAmounts: false).scheduleNotification(schedule());
    expect(notifications.bodies, ['A payment is due.']);
  });

  test('reminders show the amount after the user opted in', () async {
    await service(showAmounts: true).scheduleNotification(schedule());
    expect(notifications.bodies.single, contains('1,234.56'));
  });
}
