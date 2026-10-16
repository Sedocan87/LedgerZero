import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/sync/sync_conflicts_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/sync/sync_passphrase_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ledger_zero/presentation/widgets/sync/sync_status_indicator.dart';
import 'package:ledger_zero/presentation/screens/settings/sync_tutorial_manager.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _tutorialKeys = SyncTutorialKeys();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      SyncTutorialManager.showTutorial(context, ref, _tutorialKeys);
      ref.read(syncControllerProvider.notifier).refreshSetup();
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

    if (Platform.isIOS) {
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
      appBar: AppBar(title: Text(l10n.syncSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Provider Selection
          DropdownButtonFormField<SyncProviderType>(
            key: _tutorialKeys.provider,
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

            // Connect Button (for cloud providers)
            if (state.status == SyncStatus.disconnected ||
                state.status == SyncStatus.error)
              FilledButton.icon(
                key: _tutorialKeys.connect,
                onPressed: () => controller.connect(),
                icon: const Icon(Icons.login),
                label: Text(
                  state.selectedProvider == SyncProviderType.googleDrive
                      ? l10n.connectToGoogleDrive
                      : l10n.connectToICloud,
                ),
              ),

            if (state.status == SyncStatus.connected ||
                state.status == SyncStatus.syncing) ...[
              ..._setupSection(context, state, controller),
              if (state.setup == SyncSetupState.ready) ...[
                Text(l10n.syncPendingChanges(state.pendingChanges)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.status == SyncStatus.syncing
                      ? null
                      : () => controller.syncNow(),
                  icon: const Icon(Icons.sync),
                  label: Text(l10n.syncNow),
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: state.status == SyncStatus.syncing
                    ? null
                    : () => controller.disconnect(),
                icon: const Icon(Icons.logout),
                label: Text(l10n.disconnect),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
            ..._noticeSection(context, state, controller),

            // Error message (a generic one when the cause is unknown).
            if (state.status == SyncStatus.error || state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  switch (state.errorKind) {
                    SyncErrorKind.network => l10n.syncErrorNetwork,
                    SyncErrorKind.notSignedIn => l10n.syncErrorNotSignedIn,
                    SyncErrorKind.authFailed => l10n.syncErrorAuthFailed,
                    SyncErrorKind.storageFull => l10n.syncErrorStorageFull,
                    SyncErrorKind.iCloudUnavailable =>
                      l10n.syncErrorICloudUnavailable,
                    SyncErrorKind.other || null => l10n.syncError,
                  },
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _setupSection(
    BuildContext context,
    SyncState state,
    SyncController controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final create = state.setup == SyncSetupState.needsNewPassphrase;
    if (!create && state.setup != SyncSetupState.needsPassphrase) {
      return const [];
    }
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                create
                    ? l10n.syncPassphraseSetTitle
                    : l10n.syncPassphraseEnterTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                create
                    ? l10n.syncPassphraseSetExplanation
                    : l10n.syncPassphraseEnterExplanation,
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey('syncPassphraseButton'),
                onPressed: () => SyncPassphraseDialog.show(
                  context,
                  create: create,
                  submit: create
                      ? controller.createPassphrase
                      : controller.enterPassphrase,
                ),
                child: Text(
                  create
                      ? l10n.syncPassphraseSetButton
                      : l10n.syncPassphraseEnterButton,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _noticeSection(
    BuildContext context,
    SyncState state,
    SyncController controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final failed = state.failedFiles;
    return [
      if (state.newerSchemaPending)
        _notice(context, Icons.system_update, l10n.syncUpdateAppRequired),
      if (state.legacyFilesFound)
        _notice(context, Icons.info_outline, l10n.syncLegacyFolderFound),
      if (failed.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.syncQuarantineTitle(failed.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.syncQuarantineExplanation),
                for (final q in failed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      q.filename,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final skip = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            content: Text(l10n.syncQuarantineSkipConfirm),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: Text(
                                  MaterialLocalizations.of(
                                    dialogContext,
                                  ).cancelButtonLabel,
                                ),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: Text(l10n.syncQuarantineSkip),
                              ),
                            ],
                          ),
                        );
                        if (skip == true) {
                          await controller.skipQuarantined(q.filename);
                        }
                      },
                      child: Text(l10n.syncQuarantineSkip),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => controller.retryQuarantined(),
                      child: Text(l10n.syncQuarantineRetry),
                    ),
                    OutlinedButton(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: controller.quarantineDiagnostics()),
                      ),
                      child: Text(l10n.syncQuarantineShare),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      if (state.conflicts.isNotEmpty)
        ListTile(
          key: const ValueKey('syncConflictsTile'),
          leading: const Icon(Icons.call_split),
          title: Text(l10n.syncConflictsTitle),
          subtitle: Text(l10n.syncConflictsCount(state.conflicts.length)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SyncConflictsScreen(),
            ),
          ),
        ),
    ];
  }

  Widget _notice(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: ListTile(leading: Icon(icon), title: Text(text)),
      ),
    );
  }
}
