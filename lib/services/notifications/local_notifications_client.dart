import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// The parts of [FlutterLocalNotificationsPlugin] the app uses, so the
/// notification logic can be tested with a fake.
abstract interface class LocalNotificationsClient {
  /// Initialises the plugin; [onTap] receives the payload of a tapped
  /// notification while the app runs.
  Future<void> initialize(
    InitializationSettings settings, {
    required void Function(String? payload) onTap,
  });

  /// The payload of the notification that launched the app, if any.
  Future<String?> launchPayload();

  Future<void> show(
    int id,
    String title,
    String body,
    NotificationDetails details, {
    String? payload,
  });

  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> requestPermissions();
}

/// [LocalNotificationsClient] backed by the real plugin.
class PluginLocalNotificationsClient implements LocalNotificationsClient {
  PluginLocalNotificationsClient([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize(
    InitializationSettings settings, {
    required void Function(String? payload) onTap,
  }) async {
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    return details.notificationResponse?.payload;
  }

  @override
  Future<void> show(
    int id,
    String title,
    String body,
    NotificationDetails details, {
    String? payload,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
    payload: payload,
  );

  @override
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    String? payload,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: scheduledDate,
    notificationDetails: details,
    // A reminder does not need to the minute; exact alarms need a permission
    // that is denied by default on Android 14+ (zonedSchedule would throw).
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: payload,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }
}
