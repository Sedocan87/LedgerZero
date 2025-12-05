import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        Logger.info('Notification tapped: ${details.payload}');
      },
    );
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isMacOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) {
        Logger.warning('Cannot schedule notification in the past: $scheduledDate');
        return;
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'scheduled_transactions',
        'Scheduled Transactions',
        channelDescription: 'Notifications for upcoming scheduled transactions',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      Logger.info('Scheduled notification $id for $scheduledDate');
    } catch (e, stack) {
      Logger.error('Failed to schedule notification', e, stack);
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> showBackupReminderNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'backup_reminders',
      'Backup Reminders',
      channelDescription: 'Reminders to backup your data',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      1000, // Fixed ID for backup reminder
      'Backup Reminder',
      'It has been a while since your last backup. Tap to secure your data.',
      details,
      payload: '/settings/backup',
    );
  }

  Future<void> showSyncFailureNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'sync_status',
      'Sync Status',
      channelDescription: 'Notifications for sync status',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      999, // Fixed ID for sync failure
      title,
      body,
      details,
    );
  }

}
