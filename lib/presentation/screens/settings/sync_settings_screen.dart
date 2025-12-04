import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    // Determine available providers
    final availableProviders = [
      DropdownMenuItem(
        value: SyncProviderType.none,
        child: Text(l10n.providerNone),
      ),
      DropdownMenuItem(
        value: SyncProviderType.googleDrive,
        child: Text(l10n.providerGoogleDrive),
      ),
    ];

    if (Platform.isIOS || Platform.isMacOS) {
      availableProviders.add(
        DropdownMenuItem(
          value: SyncProviderType.iCloud,
          child: Text(l10n.providerICloud),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncSettings),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              context.pushNamed('sync-debug');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Provider Selection
          DropdownButtonFormField<SyncProviderType>(
            key: ValueKey(state.selectedProvider),
            decoration: InputDecoration(
              labelText: l10n.syncProvider,
              border: const OutlineInputBorder(),
            ),
            initialValue: state.selectedProvider,
            items: availableProviders,
            onChanged: (value) {
              if (value != null) {
                controller.setProvider(value);
              }
            },
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: Text(l10n.syncOnlyOnWifi),
            value: state.wifiOnly,
            onChanged: (value) => controller.setWifiOnly(value),
          ),
          const SizedBox(height: 24),

          // Provider Specific UI
          if (state.selectedProvider != SyncProviderType.none) ...[
            Text(
              state.selectedProvider == SyncProviderType.googleDrive
                  ? l10n.googleDriveSync
                  : l10n.iCloudDriveSync,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const SyncStatusIndicator(),
            const SizedBox(height: 24),

            // Connect Button
            if (state.status == SyncStatus.disconnected ||
                state.status == SyncStatus.error)
              FilledButton.icon(
                onPressed: () => controller.connect(),
                icon: const Icon(Icons.login),
                label: Text(
                  state.selectedProvider == SyncProviderType.googleDrive
                      ? l10n.connectToGoogleDrive
                      : l10n.connectToICloud,
                ),
              ),

            // Sync/Disconnect Buttons
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
                label: Text(l10n.disconnect),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],

            // Error Message
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'Error: ${state.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
