import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';

/// The native card notification listener (Android only).
final notificationCaptureChannelProvider = Provider<NotificationCaptureChannel>(
  (ref) => PlatformNotificationCaptureChannel(),
);

/// Books captured card notifications when the app starts or resumes (see
/// [NotificationCaptureService]).
final notificationCaptureServiceProvider = Provider<NotificationCaptureService>(
  (ref) => NotificationCaptureService(
    channel: ref.watch(notificationCaptureChannelProvider),
    transactions: ref.watch(transactionServiceProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    accounts: ref.watch(accountRepositoryProvider),
    payees: ref.watch(payeeRepositoryProvider),
    parser: CardNotificationParser(
      amountParser: ref.watch(appFormatterProvider).parser,
    ),
    authorisationMemo: ref
        .watch(appLocalizationsProvider)
        .cardNotificationsAuthorisationMemo,
  ),
);

/// What Home and Settings show about card capture: the state of the last
/// look ([attention]) and what the user has already been told.
class CaptureAttentionState {
  const CaptureAttentionState({
    this.attention = const CaptureAttention(),
    this.lastRun = const CaptureRunResult(),
    this.error,
    this.seen = const {},
    this.dismissedProblems = '',
  });

  final CaptureAttention attention;

  /// What the last run of [CaptureAttentionNotifier.process] did.
  final CaptureRunResult lastRun;

  /// Why the last run failed as a whole; `null` when it did not.
  final String? error;

  /// Ids of the notifications the user has been told about (banner
  /// dismissed, or the Card notifications screen opened).
  final Set<String> seen;

  /// [problems] as they were when the user dismissed the banner.
  final String dismissedProblems;

  /// Names the capture problems that exist now, so that a dismissed
  /// banner comes back when another one appears.
  String get problems => [
    if (attention.accessMissing) 'access',
    if (attention.listenerDisconnected) 'listener',
    if (attention.storageResetAt != null)
      'reset:${attention.storageResetAt!.millisecondsSinceEpoch}',
  ].join(',');

  /// Whether the banner still has to tell about [problems].
  bool get showProblems =>
      attention.hasProblem && problems != dismissedProblems;

  int _unseen(List<String> ids) => ids.where((id) => !seen.contains(id)).length;

  /// Waiting notifications the user has not been told about.
  int get newWaiting => _unseen(attention.waiting);

  /// Failed bookings the user has not been told about.
  int get newFailed => _unseen(attention.failed);

  /// Held duplicates the user has not been told about.
  int get newDuplicates => _unseen(attention.duplicates);

  /// Whether Home shows the banner.
  bool get showBanner =>
      attention.watching &&
      (error != null ||
          showProblems ||
          newWaiting > 0 ||
          newFailed > 0 ||
          newDuplicates > 0);

  /// The number on the Settings entry: what still needs the user (waiting
  /// and failed ones until they are handled, duplicates until seen).
  int get badgeCount => !attention.watching
      ? 0
      : (attention.hasProblem ? 1 : 0) +
            (error == null ? 0 : 1) +
            attention.waiting.length +
            attention.failed.length +
            newDuplicates;
}

/// Runs the capture pass and keeps what the user should know about it.
///
/// [process] runs when the database opens, on resume, after a capture and
/// after a sync run (the other household phone may have booked the same
/// payment; see [NotificationCaptureService]). Home shows a banner for
/// [CaptureAttentionState.showBanner] and Settings a badge.
class CaptureAttentionNotifier extends Notifier<CaptureAttentionState> {
  static const seenKey = 'card_capture_attention_seen';
  static const dismissedProblemsKey = 'card_capture_attention_problems';

  @override
  CaptureAttentionState build() => const CaptureAttentionState();

  /// Books card notifications captured since the last run (needs the open
  /// database, not the unlocked UI), then looks at what needs the user.
  Future<void> process() async {
    if (!ref.read(sessionProvider).isUnlocked) {
      return;
    }
    final capture = ref.read(notificationCaptureServiceProvider);
    if (!capture.isSupported) {
      return;
    }
    ref.read(captureAfterSyncProvider);
    var run = const CaptureRunResult();
    String? error;
    try {
      run = await capture.processPending();
    } on DatabaseLockedException {
      // Closed meanwhile (factory reset); runs again when it reopens.
      return;
    } catch (e, stackTrace) {
      Logger.error('Booking captured card notifications failed', e, stackTrace);
      error = NotificationCaptureService.describeError(e);
    }
    await refresh(run: run, error: error);
  }

  /// Reads access, listener and log again. [run] and [error] are the
  /// outcome of a run that just finished.
  Future<void> refresh({CaptureRunResult? run, String? error}) async {
    final CaptureAttention attention;
    try {
      attention = await ref
          .read(notificationCaptureServiceProvider)
          .attention();
    } on DatabaseLockedException {
      return;
    } catch (e, stackTrace) {
      Logger.error('Checking card notification capture failed', e, stackTrace);
      return;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    if (!attention.hasProblem && prefs.containsKey(dismissedProblemsKey)) {
      // Fixed: the same problem is news when it comes back.
      await prefs.remove(dismissedProblemsKey);
    }
    final listed = {
      ...attention.waiting,
      ...attention.failed,
      ...attention.duplicates,
    };
    state = CaptureAttentionState(
      attention: attention,
      lastRun: run ?? state.lastRun,
      error: run == null ? error ?? state.error : error,
      // Ids that left the log need not be remembered.
      seen: (prefs.getStringList(seenKey) ?? const <String>[])
          .where(listed.contains)
          .toSet(),
      dismissedProblems: attention.hasProblem
          ? prefs.getString(dismissedProblemsKey) ?? ''
          : '',
    );
  }

  /// The user has been told (banner dismissed, or the Card notifications
  /// screen opened): the banner stays away until something new happens.
  Future<void> markSeen() async {
    final attention = state.attention;
    final seen = {
      ...attention.waiting,
      ...attention.failed,
      ...attention.duplicates,
    };
    final problems = state.problems;
    state = CaptureAttentionState(
      attention: attention,
      lastRun: state.lastRun,
      seen: seen,
      dismissedProblems: problems,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(seenKey, seen.toList());
    await prefs.setString(dismissedProblemsKey, problems);
  }
}

final captureAttentionProvider =
    NotifierProvider<CaptureAttentionNotifier, CaptureAttentionState>(
      CaptureAttentionNotifier.new,
    );

/// The sync status as [captureAfterSyncProvider] sees it.
final captureSyncStatusProvider = Provider<SyncStatus>(
  (ref) => ref.watch(syncControllerProvider.select((s) => s.status)),
);

/// Runs the capture pass again when a sync run has ended: only then can
/// this phone see that the other one booked the same payment.
final captureAfterSyncProvider = Provider<void>((ref) {
  ref.listen<SyncStatus>(captureSyncStatusProvider, (previous, next) {
    if (previous == SyncStatus.syncing && next != SyncStatus.syncing) {
      unawaited(ref.read(captureAttentionProvider.notifier).process());
    }
  });
});
