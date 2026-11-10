// When the app asks for the notification permission (when a notification
// is first needed, not at the end of onboarding), and the Settings toggles
// that take effect at once.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/services/notifications/local_notifications_client.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../helpers/test_database.dart';

/// Records scheduled, cancelled and permission calls.
class _FakeClient implements LocalNotificationsClient {
  final scheduled = <int>[];
  final cancelled = <int>[];
  int permissionRequests = 0;

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
  }) async => scheduled.add(id);

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> requestPermissions() async => permissionRequests++;
}

void main() {
  group('NotificationPermissionGate', () {
    late bool canAsk;
    late int requests;
    late NotificationPermissionGate gate;

    setUp(() {
      canAsk = false;
      requests = 0;
      gate = NotificationPermissionGate(
        canAsk: () => canAsk,
        request: () async => requests++,
      );
    });

    test('nothing is asked until a notification is needed', () async {
      canAsk = true;
      await gate.onUiReady();
      expect(requests, 0);
    });

    test('the first notification asks at once when the app is open, and '
        'only once', () async {
      canAsk = true;
      await gate.onUse();
      await gate.onUse();
      await gate.onUiReady();
      expect(requests, 1);
    });

    test('a notification while locked or in the background asks at the '
        'next unlock or resume', () async {
      await gate.onUse();
      expect(requests, 0);
      expect(gate.pending, isTrue);
      await gate.onUiReady();
      expect(requests, 0, reason: 'still locked');

      canAsk = true;
      await gate.onUiReady();
      expect(requests, 1);
      expect(gate.pending, isFalse);
      await gate.onUiReady();
      expect(requests, 1);
    });

    test('turning a notification on asks every time', () async {
      await gate.requestNow();
      await gate.requestNow();
      expect(requests, 2);
    });
  });

  group('NotificationToggles', () {
    late TestDatabase t;
    late _FakeClient client;
    late ProviderContainer c;

    setUp(() async {
      t = TestDatabase();
      client = _FakeClient();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(t.db),
          notificationServiceProvider.overrideWithValue(
            NotificationService(client: client),
          ),
        ],
      );
      final account = await t.addAccount(id: 'acc');
      await t.scheduledTransactions.createScheduledTransaction(
        ScheduledTransaction(
          id: 's1',
          accountId: account.id,
          amount: -300,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
          nextDate: DateTime.now().toUtc().add(const Duration(days: 10)),
        ),
      );
    });

    tearDown(() async {
      c.dispose();
      await t.close();
    });

    test('turning scheduled reminders off cancels them at once', () async {
      await c.read(notificationTogglesProvider).setScheduledReminders(false);
      expect(c.read(settingsProvider).scheduledTransactionNotifications, false);
      expect(
        client.cancelled,
        contains(ScheduledTransactionService.reminderId('s1')),
      );
      expect(client.scheduled, isEmpty);
      expect(client.permissionRequests, 0);
    });

    test('turning them on asks for the permission and schedules them at '
        'once', () async {
      await c.read(notificationTogglesProvider).setScheduledReminders(false);
      await c.read(notificationTogglesProvider).setScheduledReminders(true);
      expect(c.read(settingsProvider).scheduledTransactionNotifications, true);
      expect(client.permissionRequests, 1);
      expect(client.scheduled, [ScheduledTransactionService.reminderId('s1')]);
    });

    test('turning budget or sync notifications on asks for the permission; '
        'off does not', () async {
      final toggles = c.read(notificationTogglesProvider);
      await toggles.setBudgetAlerts(false);
      await toggles.setSyncStatus(false);
      expect(client.permissionRequests, 0);
      await toggles.setBudgetAlerts(true);
      await toggles.setSyncStatus(true);
      expect(client.permissionRequests, 2);
      final settings = c.read(settingsProvider);
      expect(settings.budgetAlertNotifications, isTrue);
      expect(settings.syncStatusNotifications, isTrue);
    });
  });
}
