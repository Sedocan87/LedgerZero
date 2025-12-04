import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/sync/delta_filename_generator.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:ledger_zero/services/sync/delta_replay_service.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';

final deltaFilenameGeneratorProvider = Provider<DeltaFilenameGenerator>((ref) {
  return DeltaFilenameGenerator();
});

final localDeltaQueueProvider = Provider<LocalDeltaQueue>((ref) {
  final filenameGenerator = ref.watch(deltaFilenameGeneratorProvider);
  return LocalDeltaQueue(filenameGenerator);
});

final deltaGenerationServiceProvider = Provider<DeltaGenerationService>((ref) {
  final db = ref.watch(databaseProvider);
  final localDeltaQueue = ref.watch(localDeltaQueueProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return DeltaGenerationService(db, localDeltaQueue, prefs);
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return GoogleDriveService(authService, prefs);
});

final iCloudDriveServiceProvider = Provider<ICloudDriveService>((ref) {
  return ICloudDriveService();
});

final deltaReplayServiceProvider = Provider<DeltaReplayService>((ref) {
  final db = ref.watch(databaseProvider);
  final queue = ref.watch(localDeltaQueueProvider);
  return DeltaReplayService(db, queue);
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final genService = ref.watch(deltaGenerationServiceProvider);
  final queue = ref.watch(localDeltaQueueProvider);
  final replayService = ref.watch(deltaReplayServiceProvider);
  final driveService = ref.watch(googleDriveServiceProvider);
  final iCloudService = ref.watch(iCloudDriveServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  final engine = SyncEngine(genService, queue, replayService, driveService,
      iCloudService, prefs, connectivity, notificationService);
  ref.onDispose(engine.dispose);
  return engine;
});

final syncControllerProvider =
    StateNotifierProvider<SyncController, SyncState>((ref) {
  final authService = ref.watch(googleAuthServiceProvider);
  final iCloudService = ref.watch(iCloudDriveServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final engine = ref.watch(syncEngineProvider);
  return SyncController(
    authService,
    iCloudService,
    prefs,
    engine,
  );
});
