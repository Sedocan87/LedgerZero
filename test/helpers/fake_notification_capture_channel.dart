import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';

/// In-memory stand-in for the native listener queue.
class FakeNotificationCaptureChannel implements NotificationCaptureChannel {
  List<CaptureSource> sources = [];
  final List<CapturedNotification> queue = [];
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
  Future<List<CapturedNotification>> pending() async => List.of(queue);

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
