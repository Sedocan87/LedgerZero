import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/widgets/sync/sync_status_indicator.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_tutorial_manager.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger tutorial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SyncTutorialManager.showTutorial(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
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

    // Sync Frequencies
    final frequencies = [
      DropdownMenuItem(
        value: SyncFrequency.manual,
        child: Text(l10n.frequencyManual),
      ),
      DropdownMenuItem(
        value: SyncFrequency.realtime,
        child: Text(l10n.frequencyRealtime),
      ),
      DropdownMenuItem(
        value: SyncFrequency.every15Min,
        child: Text(l10n.frequency15Min),
      ),
      DropdownMenuItem(
        value: SyncFrequency.everyHour,
        child: Text(l10n.frequency1Hour),
      ),
      DropdownMenuItem(
        value: SyncFrequency.every4Hours,
        child: Text(l10n.frequency4Hours),
      ),
    ];

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
            key: providerKey,
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
          const SizedBox(height: 16),

          DropdownButtonFormField<SyncFrequency>(
            key: ValueKey(state.syncFrequency),
            decoration: InputDecoration(
              labelText: l10n.syncFrequency,
              border: const OutlineInputBorder(),
            ),
            initialValue: state.syncFrequency,
            items: frequencies,
            onChanged: (value) {
              if (value != null) {
                controller.setSyncFrequency(value);
              }
            },
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
                key: connectKey,
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
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
