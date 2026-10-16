import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/notifications/local_notifications_client.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

class _Shown {
  _Shown(this.id, this.title, this.body, this.details, this.payload);
  final int id;
  final String title;
  final String body;
  final NotificationDetails details;
  final String? payload;
}

/// Records what would be handed to the plugin.
class _FakeClient implements LocalNotificationsClient {
  _FakeClient({this.launch});

  final String? launch;
  int initializeCalls = 0;
  void Function(String? payload)? onTap;
  final shown = <_Shown>[];
  final scheduled = <_Shown>[];
  final cancelled = <int>[];

  @override
  Future<void> initialize(
    InitializationSettings settings, {
    required void Function(String? payload) onTap,
  }) async {
    initializeCalls++;
    this.onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> show(
    int id,
    String title,
    String body,
    NotificationDetails details, {
    String? payload,
  }) async => shown.add(_Shown(id, title, body, details, payload));

  @override
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    String? payload,
  }) async => scheduled.add(_Shown(id, title, body, details, payload));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> requestPermissions() async {}
}

void main() {
  group('NotificationPayload', () {
    test('round-trips every kind', () {
      const payloads = <NotificationPayload>[
        ScheduledReminderPayload('abc-123'),
        SyncFailurePayload(),
        BackupReminderPayload(),
        BudgetAlertPayload('cat-1'),
        BudgetAlertPayload(null),
      ];
      for (final p in payloads) {
        expect(NotificationPayload.parse(p.encode()), p);
      }
      expect(const ScheduledReminderPayload('x').encode(), 'scheduled:x');
      expect(const SyncFailurePayload().encode(), 'sync');
      expect(const BackupReminderPayload().encode(), 'backup');
      expect(const BudgetAlertPayload('c').encode(), 'budget:c');
    });

    test('keeps colons inside the id', () {
      expect(
        NotificationPayload.parse('scheduled:a:b'),
        const ScheduledReminderPayload('a:b'),
      );
    });

    test('unknown, empty and malformed payloads parse to null', () {
      expect(NotificationPayload.parse(null), isNull);
      expect(NotificationPayload.parse(''), isNull);
      expect(NotificationPayload.parse('scheduled:'), isNull);
      expect(NotificationPayload.parse('something-else'), isNull);
    });

    test('the legacy backup route payload still opens the backup', () {
      expect(
        NotificationPayload.parse('/settings/backup'),
        const BackupReminderPayload(),
      );
    });
  });

  group('NotificationIds', () {
    test('FNV-1a matches the reference values', () {
      expect(NotificationIds.fnv1a32(''), 0x811c9dc5);
      expect(NotificationIds.fnv1a32('a'), 0xe40c292c);
      expect(NotificationIds.fnv1a32('foobar'), 0xbf9cf968);
    });

    test('ids are stable, positive 31-bit and above the fixed ids', () {
      final id = NotificationIds.scheduledReminder('sched-1');
      expect(id, NotificationIds.scheduledReminder('sched-1'));
      expect(
        id,
        10000 +
            (NotificationIds.fnv1a32('scheduled:sched-1') & 0x7fffffff) %
                (0x7fffffff - 10000),
      );
      for (final key in ['', 'a', 'sched-1', 'ü-ß-€', 'x' * 500]) {
        for (final value in [
          NotificationIds.scheduledReminder(key),
          NotificationIds.budgetAlert(key),
        ]) {
          expect(value, greaterThanOrEqualTo(10000));
          expect(value, lessThanOrEqualTo(0x7fffffff));
        }
      }
      expect(
        NotificationIds.scheduledReminder('c1'),
        isNot(NotificationIds.budgetAlert('c1')),
      );
    });
  });

  group('NotificationService', () {
    void expectPrivateWithDarwin(NotificationDetails details, String channel) {
      expect(details.android, isNotNull);
      expect(details.android!.channelId, channel);
      expect(details.android!.visibility, NotificationVisibility.private);
      expect(details.iOS, isNotNull);
      expect(details.iOS!.threadIdentifier, channel);
      expect(details.macOS, isNotNull);
    }

    test('every kind has Android (private) and Darwin details', () {
      final service = NotificationService(client: _FakeClient());
      for (final kind in NotificationKind.values) {
        final details = service.detailsFor(kind);
        expectPrivateWithDarwin(details, details.android!.channelId);
      }
    });

    test('channel names come from the localised texts', () {
      final service = NotificationService(
        client: _FakeClient(),
        texts: () => const NotificationTexts(budgetChannelName: 'Budgets'),
      );
      expect(
        service.detailsFor(NotificationKind.budget).android!.channelName,
        'Budgets',
      );
    });

    test('scheduled reminders carry Darwin details and the payload', () async {
      final client = _FakeClient();
      final service = NotificationService(client: client);
      await service.scheduleNotification(
        id: 42,
        title: 't',
        body: 'b',
        scheduledDate: DateTime.now().add(const Duration(days: 2)),
        payload: 'scheduled:s1',
      );
      final s = client.scheduled.single;
      expect(s.id, 42);
      expect(s.payload, 'scheduled:s1');
      expectPrivateWithDarwin(s.details, 'scheduled_transactions');
    });

    test('backup, sync and budget notifications use typed payloads', () async {
      final client = _FakeClient();
      final service = NotificationService(
        client: client,
        texts: () => const NotificationTexts(
          backupReminderTitle: 'BT',
          backupReminderBody: 'BB',
        ),
      );
      await service.showBackupReminderNotification();
      await service.showSyncFailureNotification(title: 'ST', body: 'SB');
      await service.showBudgetAlert(categoryId: 'c1', title: 'A', body: 'B');

      expect(client.shown.map((s) => s.payload), [
        'backup',
        'sync',
        'budget:c1',
      ]);
      expect(client.shown.map((s) => s.id), [
        NotificationIds.backupReminder,
        NotificationIds.syncFailure,
        NotificationIds.budgetAlert('c1'),
      ]);
      expect(client.shown.first.title, 'BT');
      expect(client.shown.first.body, 'BB');
      expectPrivateWithDarwin(client.shown[0].details, 'backup_reminders');
      expectPrivateWithDarwin(client.shown[1].details, 'sync_status');
      expectPrivateWithDarwin(client.shown[2].details, 'budget_alerts');
    });

    test('initialises once and forwards the launch tap', () async {
      final client = _FakeClient(launch: 'sync');
      final service = NotificationService(client: client);
      final taps = <String?>[];
      service.tapHandler = taps.add;
      await service.initialize();
      await service.initialize();
      await service.showBackupReminderNotification();
      expect(client.initializeCalls, 1);
      expect(taps, ['sync']);

      client.onTap!('backup');
      expect(taps, ['sync', 'backup']);
    });

    test('taps before a handler is set are delivered to it later', () async {
      final client = _FakeClient(launch: 'scheduled:s1');
      final service = NotificationService(client: client);
      await service.initialize();
      final taps = <String?>[];
      service.tapHandler = taps.add;
      expect(taps, ['scheduled:s1']);
    });
  });
}
