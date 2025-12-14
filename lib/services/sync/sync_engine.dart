import 'dart:async';
import 'dart:io';

import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/delta_generation_service.dart';
import 'package:ledger_zero/data/models/sync_delta.dart';
import 'package:ledger_zero/services/sync/delta_replay_service.dart';
import 'package:ledger_zero/services/sync/google_drive_sync.dart';
import 'package:ledger_zero/services/sync/icloud_drive_service.dart';
import 'package:ledger_zero/services/sync/local_delta_queue.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
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
  final ConnectivityService _connectivityService;
  final NotificationService _notificationService;

  final _statusController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get statusStream => _statusController.stream;
  SyncState _currentState = const SyncState();

  final Lock _lock = Lock();
  Timer? _backgroundTimer;
  StreamSubscription<ConnectionStatus>? _connectivitySubscription;
  bool _isPaused = false;
  bool _isCancelled = false; // Task 454: Cancellation flag
  int _retryCount = 0;
  static const int _maxRetries = 5;

  SyncEngine(
    this._deltaGenerationService,
    this._deltaQueue,
    this._deltaReplayService,
    this._googleDriveService,
    this._iCloudService,
    this._prefs,
    this._connectivityService,
    this._notificationService,
  ) {
    _connectivitySubscription = _connectivityService.connectionStatusStream
        .listen((status) {
          if (status == ConnectionStatus.online) {
            Logger.info('Network restored. Triggering sync.');
            sync(background: true);
          }
        });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _backgroundTimer?.cancel();
    _statusController.close();
  }

  // Task 448: Sync Pause
  bool get isPaused => _isPaused;

  void pause() {
    _isPaused = true;
    Logger.info('SyncEngine paused.');
    _updateState(
      _currentState.copyWith(status: SyncStatus.idle, message: 'Paused'),
    );
  }

  void resume() {
    _isPaused = false;
    Logger.info('SyncEngine resumed.');
    _updateState(
      _currentState.copyWith(status: SyncStatus.idle, message: null),
    );
    // Trigger sync immediately upon resume?
    sync();
  }

  // Task 454: Sync Cancellation
  void cancel() {
    _isCancelled = true;
    Logger.info('Sync cancellation requested.');
  }

  // Task 442: Background Worker
  // Task 455: Retry on failure (exponential backoff)
  void startBackgroundSync(Duration interval) {
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(interval, (_) async {
      try {
        await sync(background: true);
        _retryCount = 0; // Reset retry count on success
      } catch (e) {
        Logger.error('Background sync failed', e);
        _scheduleRetry();
      }
    });
    Logger.info('Background sync started with interval: $interval');
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      Logger.error(
        'Max sync retries reached. Giving up until next scheduled sync.',
      );
      _notificationService.showSyncFailureNotification(
        title: 'Sync Failed',
        body: 'Max retries reached. Tap to retry manually.',
      );
      _retryCount = 0;
      return;
    }

    _retryCount++;
    final delay = Duration(
      seconds: 2 * (1 << (_retryCount - 1)),
    ); // 2, 4, 8, 16, 32...
    Logger.info('Scheduling sync retry #$_retryCount in $delay');

    // We don't block the timer, but we could schedule a one-off task.
    // However, since we have a periodic timer, maybe we should just let the next period handle it?
    // But if period is 1 hour, we want to retry sooner.
    Timer(delay, () async {
      try {
        await sync(background: true);
        // If we are here, success. _retryCount reset inside sync.
      } catch (e) {
        Logger.error('Retry #$_retryCount failed', e);
        _scheduleRetry(); // Recursive call for next retry
      }
    });
  }

  void stopBackgroundSync() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    Logger.info('Background sync stopped.');
  }

  void updateSyncFrequency(SyncFrequency frequency) {
    stopBackgroundSync();
    if (frequency == SyncFrequency.manual) {
      return;
    }

    Duration interval;
    switch (frequency) {
      case SyncFrequency.realtime:
        interval = const Duration(minutes: 5); // Polling every 5 min
        break;
      case SyncFrequency.every15Min:
        interval = const Duration(minutes: 15);
        break;
      case SyncFrequency.everyHour:
        interval = const Duration(hours: 1);
        break;
      case SyncFrequency.every4Hours:
        interval = const Duration(hours: 4);
        break;
      case SyncFrequency.manual:
        return;
    }

    startBackgroundSync(interval);
  }

  Future<void> sync({
    bool background = false,
    bool forceFullSync = false,
  }) async {
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

    if (provider == SyncProviderType.none) {
      return;
    }

    // Use lock to prevent concurrent syncs
    await _lock.synchronized(() async {
      _isCancelled = false; // Reset cancellation flag
      try {
        if (!background) {
          _updateState(
            _currentState.copyWith(
              status: SyncStatus.syncing,
              progress: 0.0,
              message: 'Starting sync...',
            ),
          );
        }
        Logger.info('Sync started (${provider.name})...');

        // 1. Generate local deltas
        if (_isCancelled) {
          return;
        }
        _updateState(
          _currentState.copyWith(message: 'Processing local changes...'),
        );
        await _deltaGenerationService.processPendingChanges();

        // Check connectivity
        if (!await _connectivityService.isConnected) {
          Logger.info('Sync deferred: Device is offline.');
          if (!background) {
            _updateState(
              _currentState.copyWith(
                status: SyncStatus.idle,
                message: 'Offline: Changes queued',
              ),
            );
          }
          return;
        }

        // Task 474: Check Wi-Fi only preference
        // Only enforce for background syncs. Manual syncs override this setting.
        if (background) {
          final wifiOnly = _prefs.getBool('sync_on_wifi_only') ?? false;
          if (wifiOnly && !await _connectivityService.isWifi) {
            Logger.info('Sync deferred: Wi-Fi only enabled and not on Wi-Fi.');
            return;
          }
        }

        // 2. Upload Pending Deltas
        if (_isCancelled) {
          return;
        }
        final pendingUploads = await _deltaQueue.getPendingDeltas();
        if (pendingUploads.isNotEmpty) {
          Logger.info('Uploading ${pendingUploads.length} pending deltas...');
          int uploadedCount = 0;
          for (final file in pendingUploads) {
            if (_isCancelled) {
              break;
            }
            _updateState(
              _currentState.copyWith(
                message:
                    'Uploading ${uploadedCount + 1}/${pendingUploads.length}',
                progress:
                    0.1 +
                    (0.2 *
                        (uploadedCount / pendingUploads.length)), // 10% to 30%
              ),
            );

            final filename = file.uri.pathSegments.last;
            if (provider == SyncProviderType.googleDrive) {
              await _googleDriveService.uploadDelta(file, filename);
            } else {
              await _iCloudService.uploadDelta(file, filename);
            }
            await _deltaQueue.markAsUploaded(file);
            uploadedCount++;
          }
        }

        if (_isCancelled) {
          Logger.info('Sync cancelled during upload.');
          _updateState(
            _currentState.copyWith(
              status: SyncStatus.idle,
              message: 'Sync cancelled',
            ),
          );
          return;
        }

        // 3. Download & Replay Remote Deltas
        _updateState(
          _currentState.copyWith(
            message: 'Checking remote files...',
            progress: 0.3,
          ),
        );

        // Task 452: Full Sync (ignore processed files)
        final processedRemoteFiles = forceFullSync
            ? <String>{}
            : await _getProcessedRemoteFiles();
        final tempDir = await getTemporaryDirectory();

        List<RemoteFile> remoteFiles = [];
        if (provider == SyncProviderType.googleDrive) {
          final files = await _googleDriveService.listDeltas();
          remoteFiles = files.map((f) => RemoteFile(f.name!, f.id!)).toList();
        } else {
          final files = await _iCloudService.listDeltas();
          remoteFiles = files
              .map((f) => RemoteFile(f.relativePath, f.relativePath))
              .toList();
        }

        remoteFiles.sort(
          (a, b) => a.name.compareTo(b.name),
        ); // Sort by name (timestamp)

        // Task 451: Incremental Sync (filter out processed)
        final pendingRemoteFiles = remoteFiles
            .where((f) => !processedRemoteFiles.contains(f.name))
            .toList();

        if (pendingRemoteFiles.isNotEmpty) {
          Logger.info('Found ${pendingRemoteFiles.length} new remote deltas.');

          // Task 459: Batch Operations (Chunking)
          const batchSize = 10;
          int processedCount = 0;
          final total = pendingRemoteFiles.length;

          for (var i = 0; i < total; i += batchSize) {
            if (_isCancelled) {
              break;
            }

            final end = (i + batchSize < total) ? i + batchSize : total;
            final batch = pendingRemoteFiles.sublist(i, end);

            _updateState(
              _currentState.copyWith(
                message: 'Downloading ${processedCount + 1}-$end/$total',
                progress: 0.3 + (0.7 * (processedCount / total)), // 30% to 100%
              ),
            );

            // Actually we read delta objects
            final downloadedDeltas = <SyncDelta>[];
            final queuedFiles = <File>[];

            // Download batch in parallel?
            // Using Future.wait might be faster but riskier on rate limits.
            // Let's do parallel for small batch.
            /*
                 await Future.wait(batch.map((remoteFile) async {
                     final savePath = '${tempDir.path}/${remoteFile.name}';
                     File downloadedFile;
                     if (provider == SyncProviderType.googleDrive) {
                         downloadedFile = await _googleDriveService.downloadDelta(remoteFile.id, savePath);
                     } else {
                         downloadedFile = await _iCloudService.downloadDelta(remoteFile.name, savePath);
                     }

                     final queuedFile = await _deltaQueue.enqueueIncoming(downloadedFile, remoteFile.name);
                     // We need to synchronize access to queuedFiles list if running in parallel?
                     // Future.wait runs concurrently. List is not thread safe?
                     // Dart is single threaded event loop, so adding to list is safe after await.
                     queuedFiles.add(queuedFile);

                     final delta = await _deltaQueue.readDelta(queuedFile);
                     downloadedDeltas.add(delta);
                 }));
                 */

            // Sort downloaded deltas by sequence/timestamp to ensure correct replay order within batch
            // Filenames are already sorted, so if we process in order of `batch`, it should be fine.
            // But Future.wait might complete out of order.
            // So we should re-sort `downloadedDeltas` or process sequentially.

            // To correspond queuedFiles with deltas, we better do it sequentially inside the loop or map carefully.
            // Let's do sequential download for safety against rate limits and ordering.

            downloadedDeltas.clear();
            queuedFiles.clear();

            for (final remoteFile in batch) {
              if (_isCancelled) {
                break;
              }
              final savePath = '${tempDir.path}/${remoteFile.name}';
              File downloadedFile;
              if (provider == SyncProviderType.googleDrive) {
                downloadedFile = await _googleDriveService.downloadDelta(
                  remoteFile.id,
                  savePath,
                );
              } else {
                downloadedFile = await _iCloudService.downloadDelta(
                  remoteFile.name,
                  savePath,
                );
              }
              final queuedFile = await _deltaQueue.enqueueIncoming(
                downloadedFile,
                remoteFile.name,
              );
              queuedFiles.add(queuedFile);
              final delta = await _deltaQueue.readDelta(queuedFile);
              downloadedDeltas.add(delta);
            }

            if (_isCancelled) {
              break;
            }

            // Replay Batch
            await _deltaReplayService.replayBatch(
              downloadedDeltas,
              filenames: batch.map((f) => f.name).toList(),
            );

            // Mark Applied
            for (final queuedFile in queuedFiles) {
              await _deltaQueue.markAsApplied(queuedFile);
            }

            processedCount += batch.length;
          }

          if (processedCount > 0) {
            Logger.info(
              'Downloaded and applied $processedCount remote deltas.',
            );
          }
        }

        if (_isCancelled) {
          Logger.info('Sync cancelled during download.');
          _updateState(
            _currentState.copyWith(
              status: SyncStatus.idle,
              message: 'Sync cancelled',
            ),
          );
          return;
        }

        final now = DateTime.now();
        await _prefs.setString('sync_last_sync_time', now.toIso8601String());
        await _recordSuccess();

        if (!background) {
          _updateState(
            _currentState.copyWith(
              status: SyncStatus.connected,
              lastSyncTime: now,
              progress: 1.0,
              message: 'Sync completed',
            ),
          );
        }
        Logger.info('Sync completed.');
        _retryCount = 0; // Reset retry on success
      } catch (e, stack) {
        Logger.error('Sync failed', e, stack);
        await _recordFailure();
        if (!background) {
          _updateState(
            _currentState.copyWith(
              status: SyncStatus.error,
              errorMessage: e.toString(),
            ),
          );
        }
        rethrow; // For background retry logic
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

  Future<void> _recordSuccess() async {
    final successCount = _prefs.getInt('sync_stats_success_count') ?? 0;
    await _prefs.setInt('sync_stats_success_count', successCount + 1);
    await _prefs.setInt('sync_stats_consecutive_failures', 0);
  }

  Future<void> _recordFailure() async {
    final failureCount = _prefs.getInt('sync_stats_failure_count') ?? 0;
    final consecutive = _prefs.getInt('sync_stats_consecutive_failures') ?? 0;
    await _prefs.setInt('sync_stats_failure_count', failureCount + 1);
    await _prefs.setInt('sync_stats_consecutive_failures', consecutive + 1);
  }

  // Task 450: Health Check
  Future<Map<String, dynamic>> checkHealth() async {
    return {
      'pending_uploads': (await _deltaQueue.getPendingDeltas()).length,
      'pending_incoming': (await _deltaQueue.getPendingIncomingDeltas()).length,
      'is_paused': _isPaused,
      'provider': _prefs.getString('sync_provider'),
      'last_sync': _prefs.getString('sync_last_sync_time'),
      'success_count': _prefs.getInt('sync_stats_success_count') ?? 0,
      'failure_count': _prefs.getInt('sync_stats_failure_count') ?? 0,
      'consecutive_failures':
          _prefs.getInt('sync_stats_consecutive_failures') ?? 0,
    };
  }
}

class RemoteFile {
  final String name;
  final String id;
  RemoteFile(this.name, this.id);
}
