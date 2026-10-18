import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';

/// In-memory stand-in for the native listener log.
class FakeNotificationCaptureChannel implements NotificationCaptureChannel {
  List<CaptureSource> sources = [];

  /// Every logged notification, pending or handled.
  final List<CapturedNotification> queue = [];

  /// Notifications [captureShowing] logs as found, by package.
  final Map<String, List<CapturedNotification>> showing = {};
  List<CandidateApp> candidates = [];
  bool accessGranted = true;
  int accessSettingsOpened = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<void> get captured => const Stream.empty();

  @override
  Future<bool> isAccessGranted() async => accessGranted;

  @override
  Future<void> openAccessSettings() async {
    accessSettingsOpened++;
  }

  @override
  Future<List<CaptureSource>> getSources() async => List.of(sources);

  @override
  Future<void> setSources(List<CaptureSource> value) async {
    sources = List.of(value);
  }

  @override
  Future<List<CandidateApp>> candidateApps() async => List.of(candidates);

  @override
  Future<List<CapturedNotification>> pending() async =>
      queue.where((n) => n.status == CaptureStatus.pending).toList();

  @override
  Future<List<CapturedNotification>> log() async => List.of(queue);

  @override
  Future<void> setStatus(
    Iterable<String> ids,
    CaptureStatus status, {
    String? transactionId,
  }) async {
    final set = ids.toSet();
    for (var i = 0; i < queue.length; i++) {
      if (set.contains(queue[i].id)) {
        queue[i] = queue[i].copyWith(
          status: status,
          transactionId: transactionId,
        );
      }
    }
  }

  @override
  Future<int> captureShowing(String packageName) async {
    final found = showing.remove(packageName) ?? const [];
    queue.addAll([
      for (final n in found) n.copyWith(status: CaptureStatus.found),
    ]);
    return found.length;
  }

  @override
  Future<void> remove(Iterable<String> ids) async {
    final drop = ids.toSet();
    queue.removeWhere((n) => drop.contains(n.id));
  }

  @override
  Future<void> clear() async {
    sources = [];
    queue.clear();
  }
}
