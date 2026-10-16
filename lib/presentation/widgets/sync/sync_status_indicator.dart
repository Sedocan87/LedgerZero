import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);
    final fmt = ref.watch(appFormatterProvider);
    final l10n = AppLocalizations.of(context)!;

    IconData icon;
    Color color;
    String statusText;

    switch (state.status) {
      case SyncStatus.connected:
      case SyncStatus.idle:
        icon = Icons.cloud_done;
        color = Colors.green;
        statusText = state.paused
            ? l10n.syncStatusPaused
            : state.accountEmail != null
            ? l10n.syncStatusConnectedAs(state.accountEmail!)
            : l10n.syncStatusConnected;
        break;
      case SyncStatus.disconnected:
        icon = Icons.cloud_off;
        color = Colors.grey;
        statusText = l10n.syncStatusDisconnected;
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        statusText = l10n.syncStatusSyncing;
        break;
      case SyncStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        // The cause (localised by kind) is shown below the card; the
        // exception's own message is technical and English.
        statusText = l10n.syncError;
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                if (state.status == SyncStatus.syncing)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  Icon(icon, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (state.lastSyncTime != null)
                        Text(
                          l10n.lastSynced(
                            fmt.formatDateTime(state.lastSyncTime!),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
