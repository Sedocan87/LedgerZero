import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/lan/lan_sync_service.dart';
import 'package:ledger_zero/services/sync/lan/local_sync_folder.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/services/sync/sync_device_id.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:path_provider/path_provider.dart';

/// Wi-Fi sync between paired phones (app lifetime). A factory reset
/// replaces it: the old one is stopped, and the new one has the new device
/// id and no pairing.
final lanSyncServiceProvider = Provider<LanSyncService>((ref) {
  ref.watch(settingsGenerationProvider);
  final service = LanSyncService(
    folder: LocalSyncFolder(
      () async => Directory(
        '${(await getApplicationDocumentsDirectory()).path}/sync/lan',
      ),
    ),
    pairingStore: LanPairingStore(ref.watch(secureStoreProvider)),
    peers: LanPeers(ref.watch(sharedPreferencesProvider)),
    deviceId: ref.watch(syncDeviceIdProvider),
    deviceName: 'Android',
  );
  if (Platform.isAndroid) {
    unawaited(
      DeviceInfoPlugin().androidInfo.then(
        (info) => service.deviceName = '${info.manufacturer} ${info.model}',
        onError: (Object _) {},
      ),
    );
  }
  ref.onDispose(service.stop);
  return service;
});

/// The paired phones, for the settings screen.
final lanPeersProvider = StreamProvider<List<LanPeer>>((ref) async* {
  final peers = ref.watch(lanSyncServiceProvider).peers;
  yield peers.all;
  yield* peers.changes;
});

/// Outgoing change files (not yet uploaded).
final syncOutboxProvider = Provider<SyncOutbox>((ref) => SyncOutbox());

/// This installation's sync device id (a new one after a factory reset).
final syncDeviceIdProvider = Provider<String>((ref) {
  ref.watch(settingsGenerationProvider);
  return SyncDeviceId.of(ref.watch(sharedPreferencesProvider));
});

/// Sync services bound to the open database. Throws while locked
/// (via [databaseProvider]); rebuilt when the database is reopened.
final syncDependenciesProvider = Provider<SyncDependencies>((ref) {
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final outbox = ref.watch(syncOutboxProvider);
  return SyncDependencies(
    // Read at engine creation: a run may have reconciled the id with the
    // database's copy (SyncDeviceId.reconcile) since the app started.
    engineFor: (transport) => SyncEngine(
      db: db,
      transport: transport,
      deviceId: SyncDeviceId.of(prefs),
      outbox: outbox,
      prefs: prefs,
    ),
    dao: db.syncDao,
    // Keep-mine deletes go through the domain deletes, which clear the
    // undo stack like any other delete.
    resolver: SyncConflictResolver(
      db,
      undoService: ref.watch(undoServiceProvider),
    ),
  );
});

/// The app-wide sync controller. Created at app start (MyApp); follows
/// [appLockStateProvider] (the database session, not the app lock): paused
/// while the database is closed, running while it is open. A factory reset
/// replaces it, so the provider and last sync time it showed (read from
/// the cleared preferences) are gone.
final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>(
  (ref) {
    ref.watch(settingsGenerationProvider);
    final lan = ref.watch(lanSyncServiceProvider);
    final controller = SyncController(
      prefs: ref.watch(sharedPreferencesProvider),
      connectivity: ref.watch(connectivityServiceProvider),
      dependencies: () => ref.read(syncDependenciesProvider),
      transportFor: (provider) => switch (provider) {
        SyncProviderType.localWifi => lan.transport,
        SyncProviderType.none => null,
      },
      lan: lan,
    );
    lan.onActivity = controller.onLanActivity;
    ref.listen<AppLockState>(
      appLockStateProvider,
      (_, next) => controller.onLockStateChanged(next),
      fireImmediately: true,
    );
    // A restore reopens the database: pick up the new connection.
    ref.listen(databaseGenerationProvider, (_, _) async {
      await controller.onLockStateChanged(AppLockState.locked);
      await controller.onLockStateChanged(ref.read(appLockStateProvider));
    });
    return controller;
  },
);
