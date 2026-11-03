import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingNotifications extends Fake implements NotificationService {
  int shown = 0;

  @override
  Future<void> showBackupReminderNotification() async => shown++;
}

void main() {
  late _CountingNotifications notifications;

  Future<BackupScheduler> scheduler(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    notifications = _CountingNotifications();
    return BackupScheduler(
      await SharedPreferences.getInstance(),
      notifications,
    );
  }

  int daysAgo(int days) =>
      DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

  test('no reminder on the first check after onboarding', () async {
    final s = await scheduler({});
    await s.checkBackupDue();
    await s.checkBackupDue();
    expect(notifications.shown, 0);
  });

  test('no backup: reminds once the interval has passed since the first '
      'check', () async {
    final s = await scheduler({
      'backup_reminder_first_check_timestamp': daysAgo(8),
    });
    await s.checkBackupDue();
    expect(notifications.shown, 1);
  });

  test('no backup: no reminder inside the interval', () async {
    final s = await scheduler({
      'backup_reminder_first_check_timestamp': daysAgo(3),
    });
    await s.checkBackupDue();
    expect(notifications.shown, 0);
  });

  test('an old backup still reminds right away', () async {
    final s = await scheduler({'last_backup_timestamp': daysAgo(10)});
    await s.checkBackupDue();
    expect(notifications.shown, 1);
  });

  test('never frequency stays silent', () async {
    final s = await scheduler({
      'backup_frequency': 'never',
      'backup_reminder_first_check_timestamp': daysAgo(100),
    });
    await s.checkBackupDue();
    expect(notifications.shown, 0);
  });
}
