import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/lan/lan_pairing.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/lan/lan_sync_service.dart';
import 'package:ledger_zero/services/sync/lan/local_sync_folder.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/services/sync/sync_device_id.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:path_provider/path_provider.dart';

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

/// One Drive transport per app session; its cached client is dropped when
/// the Google account changes (sign-out) and closed on dispose.
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  final service = GoogleDriveService(
    authService,
    ref.watch(sharedPreferencesProvider),
  );
  final subscription = authService.onCurrentUserChanged.listen(
    (_) => service.resetClient(),
    onError: (Object _) {},
  );
  ref.onDispose(() {
    subscription.cancel();
    service.dispose();
  });
  return service;
});

/// Wi-Fi sync between paired phones (app lifetime).
final lanSyncServiceProvider = Provider<LanSyncService>((ref) {
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

/// This installation's sync device id.
final syncDeviceIdProvider = Provider<String>((ref) {
  return SyncDeviceId.of(ref.watch(sharedPreferencesProvider));
});

/// Sync services bound to the open database. Throws while locked
/// (via [databaseProvider]); rebuilt when the database is reopened.
final syncDependenciesProvider = Provider<SyncDependencies>((ref) {
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final outbox = ref.watch(syncOutboxProvider);
  final deviceId = ref.watch(syncDeviceIdProvider);
  return SyncDependencies(
    engineFor: (transport) => SyncEngine(
      db: db,
      transport: transport,
      deviceId: deviceId,
      outbox: outbox,
      prefs: prefs,
    ),
    dao: db.syncDao,
    resolver: SyncConflictResolver(db),
  );
});

/// The app-wide sync controller. Created at app start (MyApp); follows
/// [appLockStateProvider] (the database session, not the app lock): paused
/// while the database is closed, running while it is open.
final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>(
  (ref) {
    final drive = ref.watch(googleDriveServiceProvider);
    final lan = ref.watch(lanSyncServiceProvider);
    final controller = SyncController(
      authService: ref.watch(googleAuthServiceProvider),
      prefs: ref.watch(sharedPreferencesProvider),
      connectivity: ref.watch(connectivityServiceProvider),
      dependencies: () => ref.read(syncDependenciesProvider),
      transportFor: (provider) => switch (provider) {
        SyncProviderType.googleDrive => drive,
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
