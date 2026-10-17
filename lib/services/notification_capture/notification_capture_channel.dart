import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// An app whose notifications are captured, and the account its card
/// payments are booked to.
class CaptureSource {
  const CaptureSource({
    required this.packageName,
    required this.label,
    this.accountId,
  });

  final String packageName;
  final String label;

  /// Account the captured transactions go to; `null` until the user picks
  /// one (captures then wait).
  final String? accountId;

  CaptureSource copyWith({String? accountId}) => CaptureSource(
    packageName: packageName,
    label: label,
    accountId: accountId ?? this.accountId,
  );

  Map<String, Object?> toJson() => {
    'packageName': packageName,
    'label': label,
    'accountId': accountId,
  };

  factory CaptureSource.fromJson(Map<String, Object?> json) => CaptureSource(
    packageName: json['packageName'] as String,
    label: json['label'] as String? ?? json['packageName'] as String,
    accountId: json['accountId'] as String?,
  );
}

/// Where an app in the picker comes from.
enum CandidateAppOrigin {
  /// It has a notification showing now.
  active,

  /// It posted a notification recently.
  recent,

  /// A known bank/card/wallet app that is installed.
  known,
}

/// An app the user can choose as a [CaptureSource].
class CandidateApp {
  const CandidateApp({
    required this.packageName,
    required this.label,
    required this.origin,
  });

  final String packageName;
  final String label;
  final CandidateAppOrigin origin;
}

/// A notification captured while the app was closed or busy, waiting to
/// become a transaction.
class CapturedNotification {
  const CapturedNotification({
    required this.id,
    required this.packageName,
    required this.appLabel,
    this.title,
    required this.text,
    required this.postedAt,
  });

  final String id;
  final String packageName;
  final String appLabel;
  final String? title;
  final String text;
  final DateTime postedAt;

  factory CapturedNotification.fromJson(Map<String, Object?> json) =>
      CapturedNotification(
        id: json['id'] as String,
        packageName: json['packageName'] as String,
        appLabel: json['appLabel'] as String? ?? json['packageName'] as String,
        title: json['title'] as String?,
        text: json['text'] as String? ?? '',
        postedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['postedAt'] as num).toInt(),
        ),
      );
}

/// Access to the native notification listener (Android only).
///
/// Native code: android/app/src/main/kotlin/com/ledgerzero/app/
/// CardNotificationListener.kt (the listener), CaptureStore.kt (sources and
/// the encrypted queue) and NotificationCaptureChannel.kt (this channel).
/// iOS gives apps no access to other apps' notifications, so
/// [isSupported] is false there and every call is a no-op.
abstract class NotificationCaptureChannel {
  bool get isSupported;

  /// Whether the user granted notification access to LedgerZero.
  Future<bool> isAccessGranted();

  /// Opens the system screen where notification access is granted.
  Future<void> openAccessSettings();

  Future<List<CaptureSource>> getSources();
  Future<void> setSources(List<CaptureSource> sources);

  /// Apps to choose from: with a notification showing, recently notifying,
  /// or known bank apps that are installed.
  Future<List<CandidateApp>> candidateApps();

  /// Captured notifications not yet turned into transactions, oldest first.
  Future<List<CapturedNotification>> pending();

  Future<void> remove(Iterable<String> ids);

  /// Deletes sources, queue and the queue key (factory reset).
  Future<void> clear();

  /// Fires when a notification was captured while the app is running.
  Stream<void> get captured;
}

class PlatformNotificationCaptureChannel implements NotificationCaptureChannel {
  PlatformNotificationCaptureChannel() {
    if (isSupported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'captured') {
          _captured.add(null);
        }
      });
    }
  }

  static const _channel = MethodChannel(
    'com.ledgerzero.app/notification_capture',
  );

  final _captured = StreamController<void>.broadcast();

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Stream<void> get captured => _captured.stream;

  @override
  Future<bool> isAccessGranted() async {
    if (!isSupported) {
      return false;
    }
    return await _channel.invokeMethod<bool>('isAccessGranted') ?? false;
  }

  @override
  Future<void> openAccessSettings() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('openAccessSettings');
    }
  }

  @override
  Future<List<CaptureSource>> getSources() async {
    if (!isSupported) {
      return const [];
    }
    return [
      for (final json in await _list('getSources'))
        CaptureSource.fromJson(json),
    ];
  }

  @override
  Future<void> setSources(List<CaptureSource> sources) async {
    if (!isSupported) {
      return;
    }
    await _channel.invokeMethod<void>('setSources', {
      'sources': jsonEncode([for (final s in sources) s.toJson()]),
    });
  }

  @override
  Future<List<CandidateApp>> candidateApps() async {
    if (!isSupported) {
      return const [];
    }
    return [
      for (final json in await _list('candidateApps'))
        CandidateApp(
          packageName: json['packageName'] as String,
          label: json['label'] as String,
          origin: CandidateAppOrigin.values.firstWhere(
            (o) => o.name == json['origin'],
            orElse: () => CandidateAppOrigin.known,
          ),
        ),
    ];
  }

  @override
  Future<List<CapturedNotification>> pending() async {
    if (!isSupported) {
      return const [];
    }
    return [
      for (final json in await _list('pending'))
        CapturedNotification.fromJson(json),
    ]..sort((a, b) => a.postedAt.compareTo(b.postedAt));
  }

  @override
  Future<void> remove(Iterable<String> ids) async {
    if (!isSupported || ids.isEmpty) {
      return;
    }
    await _channel.invokeMethod<void>('remove', {'ids': ids.toList()});
  }

  @override
  Future<void> clear() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('clear');
    }
  }

  Future<List<Map<String, Object?>>> _list(String method) async {
    final raw = await _channel.invokeMethod<String>(method) ?? '[]';
    return (jsonDecode(raw) as List).cast<Map<String, Object?>>();
  }
}
