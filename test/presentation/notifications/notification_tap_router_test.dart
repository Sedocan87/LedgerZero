import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/notifications/notification_tap_router.dart';

void main() {
  group('NotificationTapRouter', () {
    late List<String> navigated;
    late bool unlocked;
    late Set<String> schedules;

    NotificationTapRouter router() => NotificationTapRouter(
      navigate: navigated.add,
      isUnlocked: () => unlocked,
      scheduledExists: (id) async => schedules.contains(id),
    );

    setUp(() {
      navigated = [];
      unlocked = true;
      schedules = {'s1'};
    });

    test('routes each payload kind', () async {
      final r = router();
      await r.handleTap('scheduled:s1');
      await r.handleTap('sync');
      await r.handleTap('backup');
      await r.handleTap('budget:c1');
      expect(navigated, [
        '/settings/scheduled-transactions/edit/s1',
        '/settings/sync',
        '/settings/backup',
        '/budget',
      ]);
    });

    test('a deleted schedule opens the transactions list', () async {
      await router().handleTap('scheduled:gone');
      expect(navigated, ['/transactions']);
    });

    test('a failing lookup also falls back to the transactions list', () async {
      final r = NotificationTapRouter(
        navigate: navigated.add,
        isUnlocked: () => true,
        scheduledExists: (_) async => throw StateError('db closed'),
      );
      await r.handleTap('scheduled:s1');
      expect(navigated, ['/transactions']);
    });

    test('unknown payloads are ignored', () async {
      final r = router();
      await r.handleTap(null);
      await r.handleTap('');
      await r.handleTap('nonsense');
      expect(navigated, isEmpty);
      expect(r.pending, isNull);
    });

    test('a tap while locked waits until the unlock', () async {
      unlocked = false;
      final r = router();
      await r.handleTap('scheduled:s1');
      expect(navigated, isEmpty);
      expect(r.pending, isNotNull);

      // Still locked: nothing happens.
      await r.onUnlocked();
      expect(navigated, isEmpty);

      unlocked = true;
      await r.onUnlocked();
      expect(navigated, ['/settings/scheduled-transactions/edit/s1']);

      // Handled once.
      await r.onUnlocked();
      expect(navigated, hasLength(1));
      expect(r.pending, isNull);
    });

    test('only the latest tap while locked is kept', () async {
      unlocked = false;
      final r = router();
      await r.handleTap('backup');
      await r.handleTap('sync');
      unlocked = true;
      await r.onUnlocked();
      expect(navigated, ['/settings/sync']);
    });

    test('a cold-start tap (before unlock) opens after unlock', () async {
      unlocked = false;
      final r = router();
      // The launch payload is delivered like any other tap.
      await r.handleTap('budget:c1');
      unlocked = true;
      await r.onUnlocked();
      expect(navigated, ['/budget']);
    });

    test('locking while the target is resolved defers it again', () async {
      final r = NotificationTapRouter(
        navigate: navigated.add,
        isUnlocked: () => unlocked,
        scheduledExists: (id) async {
          unlocked = false;
          return true;
        },
      );
      await r.handleTap('scheduled:s1');
      expect(navigated, isEmpty);
      expect(r.pending, isNotNull);
      unlocked = true;
      await r.onUnlocked();
      // Resolving locked it again; the tap stays pending.
      expect(navigated, isEmpty);
      expect(r.pending, isNotNull);
    });
  });

  group('SyncFailureNotifications', () {
    late int shown;
    late bool enabled;

    SyncFailureNotifications notifier() => SyncFailureNotifications(
      enabled: () => enabled,
      show: () async => shown++,
    );

    const syncing = SyncState(status: SyncStatus.syncing);
    const failed = SyncState(status: SyncStatus.error, errorMessage: 'x');
    const ok = SyncState(status: SyncStatus.connected);

    setUp(() {
      shown = 0;
      enabled = true;
    });

    test('notifies when a sync run fails', () {
      notifier().onSyncState(syncing, failed);
      expect(shown, 1);
    });

    test('not when the setting is off', () {
      enabled = false;
      notifier().onSyncState(syncing, failed);
      expect(shown, 0);
    });

    test('once per failure streak, again after a successful sync', () {
      final n = notifier();
      n.onSyncState(syncing, failed);
      n.onSyncState(failed, syncing);
      n.onSyncState(syncing, failed);
      expect(shown, 1);
      n.onSyncState(failed, syncing);
      n.onSyncState(syncing, ok);
      n.onSyncState(ok, syncing);
      n.onSyncState(syncing, failed);
      expect(shown, 2);
    });

    test('errors that are not a sync run do not notify', () {
      notifier().onSyncState(ok, failed);
      notifier().onSyncState(null, failed);
      expect(shown, 0);
    });
  });
}
