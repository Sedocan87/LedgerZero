import 'dart:async';
import 'dart:io';

import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/services/sync/delta_replay_service.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

// Task 441: Sync Engine Orchestrator
class SyncEngine {
  final DeltaGenerationService _deltaGenerationService;
  final LocalDeltaQueue _deltaQueue;
  final DeltaReplayService _deltaReplayService;
  final GoogleDriveService _googleDriveService;
  final ICloudDriveService _iCloudService;
  final SharedPreferences _prefs;

  final _statusController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get statusStream => _statusController.stream;
  SyncState _currentState = const SyncState();

  final Lock _lock = Lock();
  Timer? _backgroundTimer;
  bool _isPaused = false;

  SyncEngine(
    this._deltaGenerationService,
    this._deltaQueue,
    this._deltaReplayService,
    this._googleDriveService,
    this._iCloudService,
    this._prefs,
  );

  // Task 448: Sync Pause
  bool get isPaused => _isPaused;

  void pause() {
    _isPaused = true;
    Logger.info('SyncEngine paused.');
    _updateState(_currentState.copyWith(status: SyncStatus.idle, message: 'Paused'));
  }

  void resume() {
    _isPaused = false;
    Logger.info('SyncEngine resumed.');
    _updateState(_currentState.copyWith(status: SyncStatus.idle, message: null));
    // Trigger sync immediately upon resume?
    sync();
  }

  // Task 442: Background Worker
  void startBackgroundSync(Duration interval) {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(interval, (_) {
      sync(background: true);
    });
    Logger.info('Background sync started with interval: $interval');
  }

  void stopBackgroundSync() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    Logger.info('Background sync stopped.');
  }

  Future<void> sync({bool background = false}) async {
    if (_isPaused) {
      Logger.info('Sync skipped (paused).');
      return;
    }

    // Check if we have a provider selected
    final providerStr = _prefs.getString('sync_provider');
    if (providerStr == null || providerStr == 'none') {
      return;
    }
    final provider = SyncProviderType.values.firstWhere(
      (e) => e.name == providerStr,
      orElse: () => SyncProviderType.none,
    );

    if (provider == SyncProviderType.none) return;

    // Use lock to prevent concurrent syncs
    await _lock.synchronized(() async {
      try {
        if (!background) {
            _updateState(_currentState.copyWith(status: SyncStatus.syncing));
        }
        Logger.info('Sync started (${provider.name})...');

        // 1. Generate local deltas
        await _deltaGenerationService.processPendingChanges();

        // 2. Upload Pending Deltas
        final pendingUploads = await _deltaQueue.getPendingDeltas();
        if (pendingUploads.isNotEmpty) {
           Logger.info('Uploading ${pendingUploads.length} pending deltas...');
           for (final file in pendingUploads) {
              final filename = file.uri.pathSegments.last;
              if (provider == SyncProviderType.googleDrive) {
                 await _googleDriveService.uploadDelta(file, filename);
              } else {
                 await _iCloudService.uploadDelta(file, filename);
              }
              await _deltaQueue.markAsUploaded(file);
           }
        }

        // 3. Download & Replay Remote Deltas
        final processedRemoteFiles = await _getProcessedRemoteFiles();
        final tempDir = await getTemporaryDirectory();

        List<RemoteFile> remoteFiles = [];
        if (provider == SyncProviderType.googleDrive) {
            final files = await _googleDriveService.listDeltas();
            remoteFiles = files.map((f) => RemoteFile(f.name!, f.id!)).toList();
        } else {
            final files = await _iCloudService.listDeltas();
            remoteFiles = files.map((f) => RemoteFile(f.relativePath, f.relativePath)).toList();
        }

        // Filter out files we generated or already processed
        // We might upload files we just generated, so we need to know OUR device UUID or check if we have it in uploaded folder?
        // Actually, if we just uploaded it, it's in 'uploaded' folder.
        // And we record applied deltas in SyncLog.
        // We should skip files present in SyncLog OR files present in 'uploaded' directory (our own).

        // Better: SyncLog contains applied deltas.
        // But what about our OWN deltas? We don't apply them via ReplayService (we applied them via regular app use).
        // Does SyncLog record local changes?
        // Yes, DeltaGenerationService inserts into SyncLog!
        // So SyncLog contains ALL deltas (local and remote).
        // So we just check SyncLog.

        // Optimization: We could fetch all filenames from SyncLog.
        // But listing all might be slow if huge.
        // But remoteFiles list is what we iterate.
        // For each remote file, check if it exists in SyncLog.
        // This requires an efficient check (e.g. Set<String> of processed filenames).
        // Or db check one by one?
        // If we sort remote files by timestamp, we can optimize.

        // For now, let's fetch all processed filenames from SyncLog (assuming not millions yet).
        // We can limit query to filenames in the list if needed, but `WHERE filename IN (...)` has limits.

        remoteFiles.sort((a, b) => a.name.compareTo(b.name)); // Sort by name (timestamp)

        int downloadCount = 0;
        for (final remoteFile in remoteFiles) {
             if (processedRemoteFiles.contains(remoteFile.name)) {
                 continue;
             }

             // Download
             final savePath = '${tempDir.path}/${remoteFile.name}';
             File downloadedFile;
             if (provider == SyncProviderType.googleDrive) {
                 downloadedFile = await _googleDriveService.downloadDelta(remoteFile.id, savePath);
             } else {
                 downloadedFile = await _iCloudService.downloadDelta(remoteFile.name, savePath);
             }

             // Enqueue Incoming
             final queuedFile = await _deltaQueue.enqueueIncoming(downloadedFile, remoteFile.name);

             // Replay
             final delta = await _deltaQueue.readDelta(queuedFile);
             await _deltaReplayService.replay(delta);

             // Mark Applied
             await _deltaQueue.markAsApplied(queuedFile);

             downloadCount++;
        }

        if (downloadCount > 0) {
            Logger.info('Downloaded and applied $downloadCount remote deltas.');
        }

        final now = DateTime.now();
        await _prefs.setString('sync_last_sync_time', now.toIso8601String());

        if (!background) {
            _updateState(_currentState.copyWith(status: SyncStatus.connected, lastSyncTime: now));
        }
        Logger.info('Sync completed.');

      } catch (e, stack) {
        Logger.error('Sync failed', e, stack);
        if (!background) {
            _updateState(_currentState.copyWith(status: SyncStatus.error, errorMessage: e.toString()));
        }
      }
    });
  }

  void _updateState(SyncState newState) {
    _currentState = newState;
    _statusController.add(newState);
  }

  Future<Set<String>> _getProcessedRemoteFiles() async {
      // We need a way to check if a filename is in SyncLog.
      // We can query SyncLogDao.
      // Since we don't have direct access to DAO here, we rely on a service or inject DAO?
      // DeltaReplayService has DB access. Maybe expose a method there?
      // Or pass DB to SyncEngine.
      // SyncEngine usually has high level control.
      // I'll add a method to DeltaGenerationService or DeltaReplayService to get applied filenames?
      // Or better, inject AppDatabase or SyncLogDao into SyncEngine.
      // I'll assume I can access it.
      // For now, I'll rely on SyncLogDao being available via DeltaGenerationService (it has _db).
      // I'll add a method to DeltaGenerationService to `getAppliedDeltaFilenames()`.
      return _deltaGenerationService.getAppliedDeltaFilenames();
  }

  // Task 450: Health Check
  Future<Map<String, dynamic>> checkHealth() async {
     return {
        'pending_uploads': (await _deltaQueue.getPendingDeltas()).length,
        'pending_incoming': (await _deltaQueue.getPendingIncomingDeltas()).length,
        'is_paused': _isPaused,
        'provider': _prefs.getString('sync_provider'),
        'last_sync': _prefs.getString('sync_last_sync_time'),
     };
  }
}

class RemoteFile {
    final String name;
    final String id;
    RemoteFile(this.name, this.id);
}
