import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';

/// Whether a sync provider that needs the network (Google Drive, Wi-Fi
/// pairing) is set up. Without one, being offline changes nothing.
final networkSyncConfiguredProvider = Provider<bool>((ref) {
  final provider = ref.watch(
    syncControllerProvider.select((s) => s.selectedProvider),
  );
  return provider != SyncProviderType.none;
});

/// A small "Offline mode" chip in the tab shell, shown only while there is
/// no network *and* a network sync provider is configured. The app is
/// offline-first, so without sync there is nothing to announce.
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(networkSyncConfiguredProvider)) {
      return const SizedBox.shrink();
    }
    final statusAsync = ref.watch(connectivityStatusProvider);
    if (statusAsync.valueOrNull != ConnectionStatus.offline) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Chip(
            key: const Key('offline.chip'),
            avatar: Icon(
              Icons.cloud_off,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            label: Text(AppLocalizations.of(context)!.offlineMode),
            labelStyle: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            backgroundColor: scheme.surfaceContainerHighest,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}
