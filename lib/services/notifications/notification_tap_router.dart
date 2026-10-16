import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/notifications/notification_payload.dart';

/// Turns notification taps into navigation.
///
/// * `scheduled:<id>` opens that schedule's edit screen, or the
///   transactions list if the schedule no longer exists;
/// * `sync` opens Sync settings, `backup` the Backup screen and
///   `budget:<categoryId>` the budget.
///
/// While the app is locked a tap is only remembered (the router would send
/// it to the login screen anyway, and the database cannot be read); it is
/// handled by [onUnlocked]. Only the latest pending tap is kept.
class NotificationTapRouter {
  NotificationTapRouter({
    required this.navigate,
    required this.isUnlocked,
    required this.scheduledExists,
  });

  /// Navigates to a location (go_router `go`).
  final void Function(String location) navigate;

  /// Whether the app is unlocked (onboarded and authenticated).
  final bool Function() isUnlocked;

  /// Whether the scheduled transaction still exists (needs the unlocked
  /// database).
  final Future<bool> Function(String scheduledId) scheduledExists;

  static const String scheduledEditPrefix =
      '/settings/scheduled-transactions/edit/';
  static const String transactionsRoute = '/transactions';
  static const String syncRoute = '/settings/sync';
  static const String backupRoute = '/settings/backup';
  static const String budgetRoute = '/budget';

  NotificationPayload? _pending;

  /// The tap waiting for the unlock, if any.
  NotificationPayload? get pending => _pending;

  /// Handles a tapped notification's raw [payload]. Never throws.
  Future<void> handleTap(String? payload) async {
    final parsed = NotificationPayload.parse(payload);
    if (parsed == null) {
      if (payload != null && payload.isNotEmpty) {
        Logger.warning('Ignoring notification with unknown payload');
      }
      return;
    }
    if (!isUnlocked()) {
      _pending = parsed;
      return;
    }
    await _open(parsed);
  }

  /// Handles the tap that arrived while the app was locked. Never throws.
  Future<void> onUnlocked() async {
    final pending = _pending;
    if (pending == null || !isUnlocked()) {
      return;
    }
    _pending = null;
    await _open(pending);
  }

  Future<void> _open(NotificationPayload payload) async {
    try {
      final location = await routeFor(payload);
      if (!isUnlocked()) {
        // Locked while resolving: try again after the next unlock.
        _pending = payload;
        return;
      }
      navigate(location);
    } catch (e, stack) {
      Logger.error('Failed to open notification target', e, stack);
    }
  }

  /// The location a tap on [payload] opens.
  Future<String> routeFor(NotificationPayload payload) async {
    switch (payload) {
      case ScheduledReminderPayload(:final scheduledId):
        bool exists;
        try {
          exists = await scheduledExists(scheduledId);
        } catch (e) {
          Logger.warning('Could not look up scheduled transaction: $e');
          exists = false;
        }
        return exists
            ? '$scheduledEditPrefix${Uri.encodeComponent(scheduledId)}'
            : transactionsRoute;
      case SyncFailurePayload():
        return syncRoute;
      case BackupReminderPayload():
        return backupRoute;
      case BudgetAlertPayload():
        return budgetRoute;
    }
  }
}
