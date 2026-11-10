import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupScheduler {
  final SharedPreferences _prefs;
  final NotificationService _notificationService;

  static const String _lastBackupKey = 'last_backup_timestamp';
  static const String _backupFrequencyKey = 'backup_frequency';
  static const String _lastReminderKey = 'last_backup_reminder_timestamp';
  static const String _firstCheckKey = 'backup_reminder_first_check_timestamp';

  /// Set once the stamp of [_dropOnPhoneStamp] was checked.
  static const String _offPhoneOnlyKey = 'last_backup_off_phone_only';

  /// `AutoBackupService.lastSuccessKey`.
  static const String _autoBackupSuccessKey = 'auto_backup_last_success';

  BackupScheduler(this._prefs, this._notificationService) {
    _dropOnPhoneStamp();
  }

  /// App versions before the fourth audit recorded every automatic backup
  /// as "last backup", although those files stay on the phone. A stamp
  /// written by one (within minutes after the automatic backup's own
  /// stamp) says nothing about a backup that left the phone and is
  /// dropped once; the reminder then counts from the first check like for
  /// a user without a backup.
  void _dropOnPhoneStamp() {
    if (_prefs.getBool(_offPhoneOnlyKey) ?? false) {
      return;
    }
    final last = _prefs.getInt(_lastBackupKey);
    final automatic = _prefs.getInt(_autoBackupSuccessKey);
    if (last != null &&
        automatic != null &&
        last >= automatic &&
        last - automatic < const Duration(minutes: 10).inMilliseconds) {
      _prefs.remove(_lastBackupKey);
    }
    _prefs.setBool(_offPhoneOnlyKey, true);
  }

  Future<void> checkBackupDue() async {
    final frequency =
        _prefs.getString(_backupFrequencyKey) ?? 'weekly'; // Default to weekly
    if (frequency == 'never') {
      return;
    }

    final now = DateTime.now();
    // With no backup yet, count from the first check (right after
    // onboarding) so a new user gets one full interval before the first
    // reminder, rather than a reminder on the first Home screen.
    var lastBackupMs = _prefs.getInt(_lastBackupKey);
    if (lastBackupMs == null) {
      lastBackupMs = _prefs.getInt(_firstCheckKey);
      if (lastBackupMs == null) {
        await _prefs.setInt(_firstCheckKey, now.millisecondsSinceEpoch);
        return;
      }
    }
    final lastBackup = DateTime.fromMillisecondsSinceEpoch(lastBackupMs);

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

  /// Localised, generic text (no financial data); a tap opens the Backup
  /// screen (payload `backup`).
  Future<void> _showBackupNotification() =>
      _notificationService.showBackupReminderNotification();

  /// When the last backup left the phone, null if never.
  DateTime? get lastBackup {
    final ms = _prefs.getInt(_lastBackupKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Records a backup that left the phone (shared or uploaded). Automatic
  /// backups on the phone do not count.
  Future<void> recordBackupSuccess() async {
    await _prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> setFrequency(String frequency) async {
    await _prefs.setString(_backupFrequencyKey, frequency);
  }
}
