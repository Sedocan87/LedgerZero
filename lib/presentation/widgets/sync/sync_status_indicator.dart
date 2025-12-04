import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';

class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncControllerProvider);

    IconData icon;
    Color color;
    String statusText;

    switch (state.status) {
      case SyncStatus.connected:
      case SyncStatus.idle:
        icon = Icons.cloud_done;
        color = Colors.green;
        statusText = state.accountEmail != null
            ? 'Connected as ${state.accountEmail}'
            : 'Connected';
        break;
      case SyncStatus.disconnected:
        icon = Icons.cloud_off;
        color = Colors.grey;
        statusText = 'Disconnected';
        break;
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        statusText = 'Syncing...';
        break;
      case SyncStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        statusText = state.errorMessage ?? 'Unknown Error';
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
                          'Last synced: ${DateFormat.yMMMd().add_jm().format(state.lastSyncTime!)}',
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
