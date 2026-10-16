import 'dart:convert';

/// Typed payloads of the app's local notifications.
///
/// Every notification carries one of these, encoded as a short string
/// (`scheduled:<id>`, `sync`, `backup`, `budget:<categoryId>`). Parsing lives
/// only in [NotificationPayload.parse].
sealed class NotificationPayload {
  const NotificationPayload();

  /// The string handed to the plugin.
  String encode();

  /// Parses [raw]; returns null for an unknown or empty payload.
  static NotificationPayload? parse(String? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final colon = value.indexOf(':');
    final kind = colon < 0 ? value : value.substring(0, colon);
    final arg = colon < 0 ? '' : value.substring(colon + 1);
    switch (kind) {
      case ScheduledReminderPayload.kind:
        return arg.isEmpty ? null : ScheduledReminderPayload(arg);
      case SyncFailurePayload.kind:
        return const SyncFailurePayload();
      case BackupReminderPayload.kind:
        return const BackupReminderPayload();
      case BudgetAlertPayload.kind:
        return BudgetAlertPayload(arg.isEmpty ? null : arg);
    }
    // Backup reminders shown before typed payloads carried the route.
    if (value == '/settings/backup') {
      return const BackupReminderPayload();
    }
    return null;
  }
}

/// Reminder for an upcoming occurrence of a scheduled transaction.
final class ScheduledReminderPayload extends NotificationPayload {
  static const String kind = 'scheduled';
  const ScheduledReminderPayload(this.scheduledId);
  final String scheduledId;

  @override
  String encode() => '$kind:$scheduledId';

  @override
  bool operator ==(Object other) =>
      other is ScheduledReminderPayload && other.scheduledId == scheduledId;

  @override
  int get hashCode => Object.hash(kind, scheduledId);
}

/// A sync run failed.
final class SyncFailurePayload extends NotificationPayload {
  static const String kind = 'sync';
  const SyncFailurePayload();

  @override
  String encode() => kind;

  @override
  bool operator ==(Object other) => other is SyncFailurePayload;

  @override
  int get hashCode => kind.hashCode;
}

/// A backup is overdue.
final class BackupReminderPayload extends NotificationPayload {
  static const String kind = 'backup';
  const BackupReminderPayload();

  @override
  String encode() => kind;

  @override
  bool operator ==(Object other) => other is BackupReminderPayload;

  @override
  int get hashCode => kind.hashCode;
}

/// A category became overspent this month.
final class BudgetAlertPayload extends NotificationPayload {
  static const String kind = 'budget';
  const BudgetAlertPayload(this.categoryId);
  final String? categoryId;

  @override
  String encode() => categoryId == null ? kind : '$kind:$categoryId';

  @override
  bool operator ==(Object other) =>
      other is BudgetAlertPayload && other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(kind, categoryId);
}

/// Stable notification ids.
///
/// `String.hashCode` is not guaranteed to be stable across runs or SDK
/// versions, so a reminder scheduled by one version could not be cancelled
/// by the next. These ids are a 32-bit FNV-1a hash folded into the positive
/// 31-bit range the platforms accept, above the fixed ids.
abstract final class NotificationIds {
  static const int syncFailure = 999;
  static const int backupReminder = 1000;

  /// Hashed ids start here so they never collide with the fixed ids.
  static const int _hashedBase = 10000;

  static int scheduledReminder(String scheduledId) =>
      _stable('scheduled:$scheduledId');

  static int budgetAlert(String categoryId) => _stable('budget:$categoryId');

  static int _stable(String key) {
    final hash = fnv1a32(key) & 0x7fffffff;
    return _hashedBase + hash % (0x7fffffff - _hashedBase);
  }

  /// 32-bit FNV-1a over the UTF-8 bytes of [value].
  static int fnv1a32(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}
