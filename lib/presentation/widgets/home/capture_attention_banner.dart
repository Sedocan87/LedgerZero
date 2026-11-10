import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/notification_capture_providers.dart';

/// Home: says that card notification capture needs the user (it stopped
/// capturing, payments wait, were held as duplicates or failed) and leads
/// to Settings > Card notifications. Nothing while no app is watched or
/// the user has been told (see [CaptureAttentionState.showBanner]).
class CaptureAttentionBanner extends ConsumerWidget {
  const CaptureAttentionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureAttentionProvider);
    if (!state.showBanner) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final attention = state.attention;
    // Capture that does not work is an error; payments to look at are not.
    final urgent = state.showProblems || state.error != null;
    final background = urgent
        ? scheme.errorContainer
        : scheme.secondaryContainer;
    final foreground = urgent
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    final lines = [
      if (state.showProblems && attention.accessMissing)
        l10n.cardNotificationsAttentionAccess,
      if (state.showProblems && attention.listenerDisconnected)
        l10n.cardNotificationsAttentionListener,
      if (state.showProblems && attention.storageResetAt != null)
        l10n.cardNotificationsAttentionStorageReset(
          ref.watch(appFormatterProvider).formatDate(attention.storageResetAt!),
        ),
      if (state.error != null) l10n.cardNotificationsProcessError(state.error!),
      if (state.newWaiting > 0)
        l10n.cardNotificationsAttentionWaiting(state.newWaiting),
      if (state.newDuplicates > 0)
        l10n.cardNotificationsDuplicatesHeld(state.newDuplicates),
      if (state.newFailed > 0)
        l10n.cardNotificationsAttentionFailed(state.newFailed),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        key: const Key('home.captureAttention'),
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    urgent ? Icons.notifications_off : Icons.credit_card,
                    color: foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.cardNotificationsAttentionTitle,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Text(line, style: TextStyle(color: foreground)),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('home.captureAttention.dismiss'),
                    onPressed: () =>
                        ref.read(captureAttentionProvider.notifier).markSeen(),
                    child: Text(
                      l10n.cardNotificationsDismiss,
                      style: TextStyle(color: foreground),
                    ),
                  ),
                  TextButton(
                    key: const Key('home.captureAttention.review'),
                    onPressed: () =>
                        context.push('/settings/card-notifications'),
                    child: Text(
                      l10n.cardNotificationsReview,
                      style: TextStyle(color: foreground),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
