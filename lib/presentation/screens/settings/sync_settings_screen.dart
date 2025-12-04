import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/widgets/sync/sync_status_indicator.dart';

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            l10n.googleDriveSync,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          const SyncStatusIndicator(),
          const SizedBox(height: 24),
          if (state.status == SyncStatus.disconnected ||
              state.status == SyncStatus.error)
            FilledButton.icon(
              onPressed: () => controller.connect(),
              icon: const Icon(Icons.login),
              label: Text(l10n.connectToGoogleDrive),
            ),
          if (state.status == SyncStatus.connected ||
              state.status == SyncStatus.syncing) ...[
            FilledButton.icon(
              onPressed: state.status == SyncStatus.syncing
                  ? null
                  : () {
                      controller.syncNow();
                    },
              icon: const Icon(Icons.sync),
              label: Text(l10n.syncNow),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: state.status == SyncStatus.syncing
                  ? null
                  : () => controller.disconnect(),
              icon: const Icon(Icons.logout),
              label: Text(l10n.disconnectFromGoogleDrive),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Error: ${state.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
