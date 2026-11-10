import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCapture implements NotificationCaptureService {
  CaptureAttention attentionNow = const CaptureAttention();
  CaptureRunResult run = const CaptureRunResult();
  Object? processError;
  int runs = 0;

  @override
  bool get isSupported => true;

  @override
  Future<CaptureRunResult> processPending() async {
    runs++;
    if (processError != null) {
      throw processError!;
    }
    return run;
  }

  @override
  Future<CaptureAttention> attention() async => attentionNow;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OpenSession extends SessionController {
  @override
  SessionState build() => const SessionState.open();
}

void main() {
  late _FakeCapture capture;
  late SharedPreferences prefs;
  final syncStatus = StateProvider<SyncStatus>((ref) => SyncStatus.connected);

  ProviderContainer container({bool unlocked = true, bool pro = true}) {
    final container = ProviderContainer(
      overrides: [
        // These tests use LedgerZero Pro features.
        proUnlockedProvider.overrideWithValue(pro),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationCaptureServiceProvider.overrideWithValue(capture),
        captureSyncStatusProvider.overrideWith((ref) => ref.watch(syncStatus)),
        if (unlocked) sessionProvider.overrideWith(_OpenSession.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    capture = _FakeCapture();
  });

  test('while LedgerZero Pro is locked nothing is booked', () async {
    final c = container(pro: false);
    capture.run = const CaptureRunResult(added: 2);
    await c.read(captureAttentionProvider.notifier).process();
    expect(capture.runs, 0);
    expect(c.read(captureAttentionProvider).showBanner, isFalse);

    final pro = container();
    await pro.read(captureAttentionProvider.notifier).process();
    expect(capture.runs, 1);
  });

  test('the outcome of a run is kept and shown until the user has seen '
      'it', () async {
    final c = container();
    final notifier = c.read(captureAttentionProvider.notifier);
    expect(c.read(captureAttentionProvider).showBanner, isFalse);

    capture
      ..run = const CaptureRunResult(added: 2, duplicates: 1)
      ..attentionNow = const CaptureAttention(
        watching: true,
        waiting: ['w1'],
        duplicates: ['d1'],
        failed: ['f1'],
      );
    await notifier.process();

    var state = c.read(captureAttentionProvider);
    expect(state.lastRun.duplicates, 1);
    expect(state.showBanner, isTrue);
    expect(state.newWaiting, 1);
    expect(state.newDuplicates, 1);
    expect(state.newFailed, 1);
    expect(state.badgeCount, 3);

    await notifier.markSeen();
    state = c.read(captureAttentionProvider);
    expect(state.showBanner, isFalse);
    // Waiting and failed ones still need the user; a seen duplicate does
    // not.
    expect(state.badgeCount, 2);

    // Still seen after a restart, until something new is held.
    final restarted = container();
    await restarted.read(captureAttentionProvider.notifier).process();
    expect(restarted.read(captureAttentionProvider).showBanner, isFalse);

    capture.attentionNow = const CaptureAttention(
      watching: true,
      waiting: ['w1'],
      duplicates: ['d1', 'd2'],
      failed: ['f1'],
    );
    await restarted.read(captureAttentionProvider.notifier).process();
    state = restarted.read(captureAttentionProvider);
    expect(state.showBanner, isTrue);
    expect(state.newDuplicates, 1);
    expect(state.newWaiting, 0);
  });

  test('capture that stopped is shown, and again when the cause '
      'changes', () async {
    final c = container();
    final notifier = c.read(captureAttentionProvider.notifier);
    capture.attentionNow = const CaptureAttention(
      watching: true,
      listenerDisconnected: true,
    );
    await notifier.process();
    expect(c.read(captureAttentionProvider).showProblems, isTrue);
    expect(c.read(captureAttentionProvider).showBanner, isTrue);
    expect(c.read(captureAttentionProvider).badgeCount, 1);

    await notifier.markSeen();
    await notifier.process();
    expect(c.read(captureAttentionProvider).showBanner, isFalse);
    // Settings keeps saying so.
    expect(c.read(captureAttentionProvider).badgeCount, 1);

    capture.attentionNow = const CaptureAttention(
      watching: true,
      accessMissing: true,
    );
    await notifier.process();
    expect(c.read(captureAttentionProvider).showBanner, isTrue);

    // Fixed and broken again: told again.
    await notifier.markSeen();
    capture.attentionNow = const CaptureAttention(watching: true);
    await notifier.process();
    expect(c.read(captureAttentionProvider).showBanner, isFalse);
    capture.attentionNow = const CaptureAttention(
      watching: true,
      accessMissing: true,
    );
    await notifier.process();
    expect(c.read(captureAttentionProvider).showBanner, isTrue);
  });

  test('nothing is shown while no app is watched', () async {
    final c = container();
    capture.attentionNow = const CaptureAttention();
    await c.read(captureAttentionProvider.notifier).process();
    expect(c.read(captureAttentionProvider).showBanner, isFalse);
    expect(c.read(captureAttentionProvider).badgeCount, 0);
  });

  test('a run that fails as a whole is shown with its error', () async {
    final c = container();
    capture
      ..processError = StateError('disk full')
      ..attentionNow = const CaptureAttention(watching: true);
    await c.read(captureAttentionProvider.notifier).process();

    final state = c.read(captureAttentionProvider);
    expect(state.error, 'StateError: Bad state: disk full');
    expect(state.showBanner, isTrue);

    capture.processError = null;
    await c.read(captureAttentionProvider.notifier).process();
    expect(c.read(captureAttentionProvider).error, isNull);
    expect(c.read(captureAttentionProvider).showBanner, isFalse);
  });

  test('nothing runs while the database is closed', () async {
    final c = container(unlocked: false);
    await c.read(captureAttentionProvider.notifier).process();
    expect(capture.runs, 0);
  });

  test('the pass runs again when a sync run has ended', () async {
    final c = container();
    await c.read(captureAttentionProvider.notifier).process();
    expect(capture.runs, 1);

    c.read(syncStatus.notifier).state = SyncStatus.syncing;
    await Future<void>.delayed(Duration.zero);
    expect(capture.runs, 1);

    // The other phone's booking of the same payment may have arrived.
    capture.attentionNow = const CaptureAttention(
      watching: true,
      duplicates: ['d1'],
    );
    c.read(syncStatus.notifier).state = SyncStatus.connected;
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(capture.runs, 2);
    expect(c.read(captureAttentionProvider).newDuplicates, 1);
  });
}
