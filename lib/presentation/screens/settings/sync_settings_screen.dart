import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/widgets/help/info_button.dart';
import 'package:ledger_zero/presentation/widgets/help/help_topics.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/sync/lan_pairing_screens.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/presentation/screens/settings/sync/sync_conflicts_screen.dart';
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

  /// Starting or joining Wi-Fi sync is in progress.
  bool _busy = false;

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

    final availableProviders = [
      DropdownMenuItem(
        value: SyncProviderType.none,
        child: Text(l10n.providerNone),
      ),
      DropdownMenuItem(
        value: SyncProviderType.localWifi,
        child: Text(l10n.providerLocalWifi, overflow: TextOverflow.ellipsis),
      ),
    ];

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
        actions: const [InfoButton(HelpTopic.sync)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Provider Selection
          DropdownButtonFormField<SyncProviderType>(
            key: _tutorialKeys.provider,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.syncProvider,
              border: const OutlineInputBorder(),
            ),
            initialValue: state.selectedProvider,
            items: availableProviders,
            onChanged: (value) {
              if (value != null) {
                _changeProvider(value);
              }
            },
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

          // Wi-Fi sync (the only provider besides "None").
          if (state.selectedProvider == SyncProviderType.localWifi) ...[
            Text(
              l10n.lanSyncTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            const SyncStatusIndicator(),
            const SizedBox(height: 24),

            if (state.setup != SyncSetupState.ready)
              ..._lanSetupSection(context),
            if (state.setup == SyncSetupState.ready)
              ..._lanPeersSection(context),
            if ((state.status == SyncStatus.connected ||
                    state.status == SyncStatus.syncing) &&
                state.setup == SyncSetupState.ready) ...[
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
              OutlinedButton.icon(
                onPressed: state.status == SyncStatus.syncing
                    ? null
                    : _turnOffLan,
                icon: const Icon(Icons.logout),
                label: Text(l10n.lanTurnOff),
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
                    SyncErrorKind.pairingMismatch =>
                      l10n.syncErrorPairingMismatch,
                    SyncErrorKind.clockSkew => l10n.syncErrorClockSkew(
                      (state.peerClockSkew?.inMinutes ?? 0).abs(),
                    ),
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

  /// Asks before an action that stops this phone from syncing. Returns
  /// whether the user confirmed.
  Future<bool> _confirmStop({
    required String title,
    required String message,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('sync_stop_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Provider dropdown: choosing "None" while a provider is set stops sync
  /// and is confirmed first.
  Future<void> _changeProvider(SyncProviderType value) async {
    final controller = ref.read(syncControllerProvider.notifier);
    final current = ref.read(syncControllerProvider).selectedProvider;
    if (value == SyncProviderType.none && current != SyncProviderType.none) {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await _confirmStop(
        title: l10n.syncProviderNoneConfirmTitle,
        message: l10n.syncProviderNoneConfirmMessage,
        action: l10n.syncStopAction,
      );
      if (!confirmed) {
        // The dropdown already shows "None": back to the provider in use.
        final field = _tutorialKeys.provider.currentState;
        if (field is FormFieldState<SyncProviderType>) {
          field.didChange(current);
        }
        return;
      }
    }
    await controller.setProvider(value);
  }

  Future<void> _turnOffLan() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirmStop(
      title: l10n.lanTurnOffConfirmTitle,
      message: l10n.lanTurnOffConfirmMessage,
      action: l10n.lanTurnOff,
    );
    if (confirmed) {
      await ref.read(syncControllerProvider.notifier).disconnect();
    }
  }

  /// Wi-Fi sync before pairing: start on this phone or join another.
  List<Widget> _lanSetupSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.lanSetupExplanation),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('lan_start'),
                onPressed: _busy ? null : _startLan,
                icon: const Icon(Icons.wifi_tethering),
                label: Text(l10n.lanStart),
              ),
              const SizedBox(height: 4),
              Text(l10n.lanStartHint, style: _hintStyle(context)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('lan_join'),
                onPressed: _busy ? null : _joinLan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n.lanJoin),
              ),
              const SizedBox(height: 4),
              Text(l10n.lanJoinHint, style: _hintStyle(context)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Wi-Fi sync after pairing: the paired phones and "Pair a phone".
  List<Widget> _lanPeersSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final peers = ref.watch(lanPeersProvider).value ?? const [];
    final formatter = ref.watch(appFormatterProvider);
    String synced(DateTime time) => l10n.lanPeerLastSync(
      '${formatter.formatDate(time)} '
      '${TimeOfDay.fromDateTime(time).format(context)}',
    );
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(
                  l10n.lanPeersTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (peers.isEmpty) ListTile(title: Text(l10n.lanNoPeers)),
              for (final peer in peers)
                ListTile(
                  leading: const Icon(Icons.smartphone),
                  title: Text(peer.name),
                  subtitle: Text(
                    peer.lastSync == null
                        ? l10n.lanPeerNeverSynced
                        : synced(peer.lastSync!),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: OutlinedButton.icon(
                  key: const Key('lan_pair_phone'),
                  onPressed: () => LanShowCodeScreen.show(context),
                  icon: const Icon(Icons.qr_code),
                  label: Text(l10n.lanPairPhone),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  TextStyle? _hintStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall;

  Future<void> _startLan() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result = await ref
        .read(syncControllerProvider.notifier)
        .startLanSync();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result == LanSetupResult.ok ? l10n.lanStarted : l10n.lanSetupFailed,
        ),
      ),
    );
  }

  /// Joining a folder merges this phone's data into the shared budget;
  /// accounts of the same name on both phones end up twice. Asks first when
  /// there is anything to merge. Returns whether to go on.
  Future<bool> _confirmMergeExistingData() async {
    final l10n = AppLocalizations.of(context)!;
    final accounts = await ref.read(accountRepositoryProvider).getAllAccounts();
    final transactions = await ref
        .read(transactionRepositoryProvider)
        .getAllTransactions();
    if (accounts.isEmpty && transactions.isEmpty) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.syncJoinExistingDataTitle),
        content: Text(
          l10n.syncJoinExistingDataMessage(
            accounts.length,
            transactions.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('sync_join_merge_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.syncJoinExistingDataConfirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _joinLan() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirmMergeExistingData() || !mounted) {
      return;
    }
    final code = await LanScanCodeScreen.show(context);
    if (code == null || code.isEmpty || !mounted) {
      return;
    }
    setState(() => _busy = true);
    messenger.showSnackBar(SnackBar(content: Text(l10n.lanJoining)));
    final result = await ref
        .read(syncControllerProvider.notifier)
        .joinLanSync(code);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            LanSetupResult.ok => l10n.lanJoined,
            LanSetupResult.invalidCode => l10n.lanInvalidCode,
            LanSetupResult.phoneNotFound => l10n.lanPhoneNotFound,
            LanSetupResult.clockSkew => l10n.syncErrorClockSkew(
              (ref.read(syncControllerProvider).peerClockSkew?.inMinutes ?? 0)
                  .abs(),
            ),
            LanSetupResult.failed => l10n.lanSetupFailed,
          }),
        ),
      );
  }

  List<Widget> _noticeSection(
    BuildContext context,
    SyncState state,
    SyncController controller,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final failed = state.failedFiles;
    final foreign = state.foreignFiles;
    return [
      if (state.newerSchemaPending)
        _notice(context, Icons.system_update, l10n.syncUpdateAppRequired),
      if (state.legacyFilesFound)
        _notice(context, Icons.info_outline, l10n.syncLegacyFolderFound),
      if (state.clockSkewSuspected)
        _notice(context, Icons.schedule, l10n.syncClockNotice),
      if (foreign.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            key: const ValueKey('syncForeignFiles'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.syncForeignFilesTitle(foreign.length),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.syncForeignFilesExplanation),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => controller.removeForeignFiles(),
                        child: Text(l10n.syncForeignRemove),
                      ),
                      OutlinedButton(
                        onPressed: () => controller.ignoreForeignFiles(),
                        child: Text(l10n.syncForeignIgnore),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
