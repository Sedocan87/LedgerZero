import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/privacy_settings_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/router/app_router.dart';
import 'package:ledger_zero/services/notifications/budget_alert_producer.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/notifications/notification_tap_router.dart';

/// Channel names and fixed texts in the app language.
NotificationTexts notificationTextsFor(AppLocalizations l10n) =>
    NotificationTexts(
      scheduledChannelName: l10n.notificationChannelScheduledName,
      scheduledChannelDescription: l10n.notificationChannelScheduledDescription,
      backupChannelName: l10n.notificationChannelBackupName,
      backupChannelDescription: l10n.notificationChannelBackupDescription,
      syncChannelName: l10n.notificationChannelSyncName,
      syncChannelDescription: l10n.notificationChannelSyncDescription,
      budgetChannelName: l10n.notificationChannelBudgetName,
      budgetChannelDescription: l10n.notificationChannelBudgetDescription,
      backupReminderTitle: l10n.notificationBackupTitle,
      backupReminderBody: l10n.notificationBackupBody,
      openActionName: l10n.notificationOpenAction,
    );

/// Routes notification taps; taps while locked wait for the unlock.
final notificationTapRouterProvider = Provider<NotificationTapRouter>((ref) {
  return NotificationTapRouter(
    isUnlocked: () {
      final auth = ref.read(authProvider);
      return auth.isOnboarded && auth.isAuthenticated;
    },
    scheduledExists: (id) async =>
        await ref
            .read(scheduledTransactionRepositoryProvider)
            .getScheduledTransactionById(id) !=
        null,
    navigate: (location) {
      // An unlock re-runs the router's redirect (the lock screen leaves
      // for Home); go once that frame is done.
      final binding = WidgetsBinding.instance;
      binding.addPostFrameCallback(
        // Home with the tab bar underneath, so back leads into the app.
        (_) => openOnTopOfHome(ref.read(routerProvider), location),
      );
      binding.scheduleFrame();
    },
  );
});

/// The overspent-category alert (Settings > Notifications > Budget alerts).
final budgetAlertProducerProvider = Provider<BudgetAlertProducer>((ref) {
  final notifications = ref.watch(notificationServiceProvider);
  return BudgetAlertProducer(
    prefs: ref.watch(sharedPreferencesProvider),
    categoryAvailable: (categoryId, month) => ref
        .read(budgetingServiceProvider)
        .calculateCategoryAvailable(categoryId, month),
    notify: notifications.showBudgetAlert,
    enabled: () => ref.read(settingsProvider).budgetAlertNotifications,
    showAmounts: () => ref.read(privacySettingsProvider).notificationAmounts,
    categoryName: (id) async =>
        (await ref.read(categoryRepositoryProvider).getCategoryById(id))?.name,
    text: (details) {
      final l10n = appLocalizationsFor(ref);
      return (
        title: l10n.notificationBudgetAlertTitle,
        body: details == null
            ? l10n.notificationBudgetAlertBodyGeneric
            : l10n.notificationBudgetAlertBodyAmount(
                details.categoryName,
                ref.read(appFormatterProvider).formatMoney(details.overspent),
              ),
      );
    },
  );
});

/// Shows the sync-failure notification when a sync run fails (Settings >
/// Notifications > Sync status). One notification per failure streak: it
/// is shown again only after a sync succeeded.
class SyncFailureNotifications {
  SyncFailureNotifications({
    required this.enabled,
    required this.show,
    this.showUpdateRequired,
    this.updateNoticeDue,
  });

  final bool Function() enabled;
  final Future<void> Function() show;

  /// Shows "another device uses a newer version, update the app".
  final Future<void> Function()? showUpdateRequired;

  /// Whether that notice may be shown now (it is repeated at most every
  /// [updateNoticeEvery] while the other device stays ahead); calling it
  /// with `true` as the result records the notice.
  final bool Function()? updateNoticeDue;

  static const Duration updateNoticeEvery = Duration(days: 3);
  bool _notified = false;

  void onSyncState(SyncState? previous, SyncState next) {
    _onNewerSchema(previous, next);
    if (previous?.status != SyncStatus.syncing) {
      return;
    }
    if (next.status == SyncStatus.connected) {
      _notified = false;
      return;
    }
    if (next.status != SyncStatus.error || _notified || !enabled()) {
      return;
    }
    _notified = true;
    unawaited(show());
  }

  /// A change file of a newer app version started waiting: the partner's
  /// changes do not arrive until this phone is updated, and nothing else
  /// looks wrong.
  void _onNewerSchema(SyncState? previous, SyncState next) {
    final showUpdate = showUpdateRequired;
    if (showUpdate == null ||
        !next.newerSchemaPending ||
        (previous?.newerSchemaPending ?? false) ||
        !enabled() ||
        !(updateNoticeDue?.call() ?? true)) {
      return;
    }
    unawaited(showUpdate());
  }
}

final syncFailureNotificationsProvider = Provider<SyncFailureNotifications>((
  ref,
) {
  const updateNoticeKey = 'sync_update_notice_timestamp';
  return SyncFailureNotifications(
    enabled: () => ref.read(settingsProvider).syncStatusNotifications,
    show: () {
      final l10n = appLocalizationsFor(ref);
      return ref
          .read(notificationServiceProvider)
          .showSyncFailureNotification(
            title: l10n.notificationSyncFailedTitle,
            body: l10n.notificationSyncFailedBody,
          );
    },
    // Same notification slot and tap target (Sync settings) as a failure.
    showUpdateRequired: () {
      final l10n = appLocalizationsFor(ref);
      return ref
          .read(notificationServiceProvider)
          .showSyncFailureNotification(
            title: l10n.notificationSyncUpdateTitle,
            body: l10n.notificationSyncUpdateBody,
          );
    },
    updateNoticeDue: () {
      final prefs = ref.read(sharedPreferencesProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(updateNoticeKey);
      if (last != null &&
          now - last <
              SyncFailureNotifications.updateNoticeEvery.inMilliseconds) {
        return false;
      }
      unawaited(prefs.setInt(updateNoticeKey, now));
      return true;
    },
  );
});
