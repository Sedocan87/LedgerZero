import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/notifications/local_notifications_client.dart';
import 'package:ledger_zero/services/notifications/notification_payload.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

export 'package:ledger_zero/services/notifications/notification_payload.dart';

/// Localised channel names and fixed notification texts.
///
/// Passed in by the provider (app language); the English defaults are only
/// used where no localisation is available (tests).
class NotificationTexts {
  const NotificationTexts({
    this.scheduledChannelName = 'Scheduled transactions',
    this.scheduledChannelDescription =
        'Reminders for upcoming scheduled transactions',
    this.backupChannelName = 'Backup reminders',
    this.backupChannelDescription = 'Reminders to back up your data',
    this.syncChannelName = 'Sync status',
    this.syncChannelDescription = 'Notifications when a sync fails',
    this.budgetChannelName = 'Budget alerts',
    this.budgetChannelDescription = 'Alerts when a category is overspent',
    this.backupReminderTitle = 'Backup reminder',
    this.backupReminderBody =
        'It has been a while since your last backup. Tap to back up your data.',
    this.openActionName = 'Open',
  });

  final String scheduledChannelName;
  final String scheduledChannelDescription;
  final String backupChannelName;
  final String backupChannelDescription;
  final String syncChannelName;
  final String syncChannelDescription;
  final String budgetChannelName;
  final String budgetChannelDescription;
  final String backupReminderTitle;
  final String backupReminderBody;

  /// Linux default action label.
  final String openActionName;
}

/// The kinds of notification the app shows (one Android channel and one iOS
/// thread each).
enum NotificationKind { scheduled, backup, sync, budget }

/// Shows and schedules the app's local notifications.
///
/// Privacy (WP3): callers keep amounts out of the text unless the user
/// opted in; every notification is [NotificationVisibility.private] on
/// Android, so a secure lock screen shows only "contents hidden" (the
/// plugin has no custom public version), and on iOS the system preview
/// setting applies (by default previews only when unlocked).
///
/// Taps are passed to [tapHandler] with the raw payload (parse it with
/// [NotificationPayload.parse]); a tap that arrives before a handler is set,
/// and the tap that launched the app, are kept until one is.
class NotificationService {
  NotificationService({
    LocalNotificationsClient? client,
    NotificationTexts Function()? texts,
  }) : _client = client ?? PluginLocalNotificationsClient(),
       _texts = texts ?? _defaultTexts;

  static NotificationTexts _defaultTexts() => const NotificationTexts();

  final LocalNotificationsClient _client;
  final NotificationTexts Function() _texts;
  Future<void>? _initialization;
  void Function(String? payload)? _tapHandler;
  final List<String?> _undeliveredTaps = [];

  /// Receives the payload of every tapped notification.
  set tapHandler(void Function(String? payload)? handler) {
    _tapHandler = handler;
    if (handler == null) {
      return;
    }
    final pending = List.of(_undeliveredTaps);
    _undeliveredTaps.clear();
    pending.forEach(handler);
  }

  void _onTap(String? payload) {
    final handler = _tapHandler;
    if (handler == null) {
      _undeliveredTaps.add(payload);
    } else {
      handler(payload);
    }
  }

  /// Initialises the plugin once per process (later calls return the same
  /// future) and forwards the tap that launched the app, if any.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      tz.initializeTimeZones();
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final settings = InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
        linux: LinuxInitializationSettings(
          defaultActionName: _texts().openActionName,
        ),
      );
      await _client.initialize(settings, onTap: _onTap);
      final launch = await _client.launchPayload();
      if (launch != null) {
        _onTap(launch);
      }
    } catch (e, stack) {
      Logger.error('Failed to initialise notifications', e, stack);
    }
  }

  /// The OS permission dialog makes the app `inactive`; [ExternalUiGuard]
  /// keeps the immediate auto-lock from locking for it.
  Future<void> requestPermissions() async {
    try {
      await ExternalUiGuard.run(_client.requestPermissions);
    } catch (e, stack) {
      Logger.error('Failed to request notification permission', e, stack);
    }
  }

  /// Platform details for [kind]: Android channel (private visibility) and
  /// iOS/macOS thread.
  NotificationDetails detailsFor(NotificationKind kind) {
    final texts = _texts();
    final (
      String channelId,
      String name,
      String description,
      Importance importance,
      Priority priority,
    ) = switch (kind) {
      NotificationKind.scheduled => (
        'scheduled_transactions',
        texts.scheduledChannelName,
        texts.scheduledChannelDescription,
        Importance.high,
        Priority.high,
      ),
      NotificationKind.backup => (
        'backup_reminders',
        texts.backupChannelName,
        texts.backupChannelDescription,
        Importance.defaultImportance,
        Priority.defaultPriority,
      ),
      NotificationKind.sync => (
        'sync_status',
        texts.syncChannelName,
        texts.syncChannelDescription,
        Importance.defaultImportance,
        Priority.defaultPriority,
      ),
      NotificationKind.budget => (
        'budget_alerts',
        texts.budgetChannelName,
        texts.budgetChannelDescription,
        Importance.high,
        Priority.high,
      ),
    };
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      threadIdentifier: channelId,
    );
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        name,
        channelDescription: description,
        importance: importance,
        priority: priority,
        // Secure lock screens show "contents hidden".
        visibility: NotificationVisibility.private,
      ),
      iOS: darwin,
      macOS: darwin,
    );
  }

  /// Schedules a reminder. [payload] is an encoded [NotificationPayload].
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) {
        Logger.warning(
          'Cannot schedule notification in the past: $scheduledDate',
        );
        return;
      }
      await initialize();
      await _client.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        detailsFor(NotificationKind.scheduled),
        payload: payload,
      );
      Logger.info('Scheduled notification $id for $scheduledDate');
    } catch (e, stack) {
      Logger.error('Failed to schedule notification', e, stack);
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _client.cancel(id);
    } catch (e, stack) {
      Logger.error('Failed to cancel notification', e, stack);
    }
  }

  Future<void> showBackupReminderNotification() async {
    final texts = _texts();
    await _show(
      NotificationIds.backupReminder,
      texts.backupReminderTitle,
      texts.backupReminderBody,
      NotificationKind.backup,
      const BackupReminderPayload(),
    );
  }

  /// [title] and [body] must be generic (no financial data).
  Future<void> showSyncFailureNotification({
    required String title,
    required String body,
  }) => _show(
    NotificationIds.syncFailure,
    title,
    body,
    NotificationKind.sync,
    const SyncFailurePayload(),
  );

  /// Overspent-category alert. [body] contains amounts or the category
  /// name only if the user opted in to amounts in notifications.
  Future<void> showBudgetAlert({
    required String categoryId,
    required String title,
    required String body,
  }) => _show(
    NotificationIds.budgetAlert(categoryId),
    title,
    body,
    NotificationKind.budget,
    BudgetAlertPayload(categoryId),
  );

  Future<void> _show(
    int id,
    String title,
    String body,
    NotificationKind kind,
    NotificationPayload payload,
  ) async {
    try {
      await initialize();
      await _client.show(
        id,
        title,
        body,
        detailsFor(kind),
        payload: payload.encode(),
      );
    } catch (e, stack) {
      Logger.error('Failed to show ${kind.name} notification', e, stack);
    }
  }
}
