import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupScheduler {
  final SharedPreferences _prefs;
  final NotificationService _notificationService;

  static const String _lastBackupKey = 'last_backup_timestamp';
  static const String _backupFrequencyKey = 'backup_frequency';
  static const String _lastReminderKey = 'last_backup_reminder_timestamp';

  BackupScheduler(this._prefs, this._notificationService);

  Future<void> checkBackupDue() async {
    final frequency = _prefs.getString(_backupFrequencyKey) ?? 'weekly'; // Default to weekly
    if (frequency == 'never') {
      return;
    }

    final lastBackupMs = _prefs.getInt(_lastBackupKey) ?? 0;
    // If no backup ever, treat as epoch 0 (1970), so it's definitely due.
    final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupMs);
    final now = DateTime.now();

    bool isDue = false;
    switch (frequency) {
      case 'daily':
        isDue = now.difference(lastBackup).inDays >= 1;
        break;
      case 'weekly':
        isDue = now.difference(lastBackup).inDays >= 7;
        break;
      case 'monthly':
        isDue = now.difference(lastBackup).inDays >= 30;
        break;
    }

    if (isDue) {
      final lastReminderMs = _prefs.getInt(_lastReminderKey) ?? 0;
      final lastReminder = DateTime.fromMillisecondsSinceEpoch(lastReminderMs);

      // Remind at most once every 24 hours if overdue
      if (now.difference(lastReminder).inHours >= 24) {
         await _showBackupNotification();
         await _prefs.setInt(_lastReminderKey, now.millisecondsSinceEpoch);
      }
    }
  }

  Future<void> _showBackupNotification() async {
    // We add a new method to NotificationService to expose generic show functionality
    // or use existing one if suitable.
    // Since NotificationService has showSyncFailureNotification, we can add showBackupNotification.
    // For now, I will use reflection/dynamic or just assume I can add it to the service class later.
    // I'll update NotificationService in the next step to support generic notifications.

    // Actually, NotificationService doesn't expose the plugin, so I must add a method to it.
    await _notificationService.showBackupReminderNotification();
  }

  Future<void> recordBackupSuccess() async {
    await _prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> setFrequency(String frequency) async {
    await _prefs.setString(_backupFrequencyKey, frequency);
  }
}
