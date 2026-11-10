import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/constants/default_categories.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/presentation/providers/review_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/notifications/local_notifications_client.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/purchases/pro_store.dart';
import 'package:ledger_zero/services/review/review_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Demo mode for store screenshots (StoreScreenshotKit): sample data in an
/// in-memory database, nothing of the user's.
///
/// Only with `--dart-define=LEDGERZERO_DEMO=true` in a debug or profile
/// build, and only under an application id ending in `.demo` (build with
/// `-Pdemo=true`, which installs next to the normal app):
///
/// ```bash
/// flutter build apk --debug --flavor development -t lib/main_development.dart \
///   -Pdemo=true --dart-define=LEDGERZERO_DEMO=true
/// ```
///
/// Every launch starts fresh: an in-memory database seeded by
/// `demo_data.dart`, preferences under their own prefix and cleared, Pro
/// unlocked without a store, no notifications, no rating prompt.
/// `LEDGERZERO_DEMO_THEME` picks `dark` (default) or `light`.
const bool kDemoMode = bool.fromEnvironment('LEDGERZERO_DEMO') && !kReleaseMode;

const String _demoTheme = String.fromEnvironment(
  'LEDGERZERO_DEMO_THEME',
  defaultValue: 'dark',
);

/// The demo's preferences live under their own prefix, so nothing of a
/// normal install could ever be read or overwritten.
const String demoPreferencesPrefix = 'ledgerzero_demo.';

/// Refuses to run the demo unless the app id ends in `.demo`.
Future<void> ensureDemoInstall() async {
  final info = await PackageInfo.fromPlatform();
  if (!info.packageName.endsWith('.demo')) {
    throw StateError(
      'Demo mode needs the demo app id (build with -Pdemo=true), '
      'not ${info.packageName}.',
    );
  }
}

/// Fresh demo preferences: onboarded, tutorials and offers done, no app
/// lock, English, dollars, Pro unlocked.
Future<SharedPreferences> prepareDemoPreferences() async {
  SharedPreferences.setPrefix(demoPreferencesPrefix);
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  await prefs.setBool('user_onboarded', true);
  for (final id in [
    'budget_screen_intro',
    'transaction_entry_intro',
    'sync_setup_intro',
  ]) {
    await prefs.setBool('tutorial_completed_$id', true);
  }
  await prefs.setBool('salary_prompt_handled', true);
  await prefs.setBool('savings_categories_offer_handled', true);
  await prefs.setString('theme_mode', 'ThemeMode.$_demoTheme');
  await prefs.setString('settings_language', 'en');
  await prefs.setString('settings_currency', 'USD');
  // Dollars with US dates.
  await prefs.setInt('settings_date_format', AppDateFormat.us.index);
  await prefs.setBool('budget_tutorial_dismissed', true);
  // The one-time month cards: handled for the recent months.
  final thisMonth = CalendarDate.startOfMonthUtc(CalendarDate.today());
  final recentMonths = [
    for (var i = 0; i < 7; i++)
      CalendarDate.monthKey(DateTime.utc(thisMonth.year, thisMonth.month - i)),
  ];
  await prefs.setStringList('leftover_card_dismissed', recentMonths);
  await prefs.setStringList('new_month_offer_dismissed', recentMonths);
  await prefs.setBool(ProController.unlockedKey, true);
  for (final key in [
    'settings_notif_scheduled_tx',
    'settings_notif_budget_alert',
    'settings_notif_sync_status',
  ]) {
    await prefs.setBool(key, false);
  }
  return prefs;
}

/// A fresh in-memory database with the default categories.
AppDatabase demoDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory(), seedName: (name) => name);
}

/// What the demo replaces: the database, the store, notifications and the
/// rating prompt.
List<Override> demoOverrides(SharedPreferences prefs, AppDatabase db) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  databaseProvider.overrideWithValue(db),
  // Pro is unlocked in the preferences; no store may say otherwise.
  proStoreProvider.overrideWithValue(const UnavailableProStore()),
  reviewClientProvider.overrideWithValue(const NoReviewClient()),
  notificationServiceProvider.overrideWithValue(
    NotificationService(client: _NoNotifications()),
  ),
];

/// Swallows every notification call.
class _NoNotifications implements LocalNotificationsClient {
  @override
  Future<void> initialize(
    InitializationSettings settings, {
    required void Function(String? payload) onTap,
  }) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<void> show(
    int id,
    String title,
    String body,
    NotificationDetails details, {
    String? payload,
  }) async {}

  @override
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    String? payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> requestPermissions() async {}
}

/// The seeded category names (English), for the demo data.
const demoGroups = DefaultCategories.groups;
