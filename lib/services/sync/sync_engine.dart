import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/sync/change_applier.dart';
import 'package:ledger_zero/services/sync/change_generator.dart';
import 'package:ledger_zero/services/sync/format/sync_change.dart';
import 'package:ledger_zero/services/sync/format/sync_file_codec.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/format/sync_manifest.dart';
import 'package:ledger_zero/services/sync/personal_rows.dart';
import 'package:ledger_zero/services/sync/sync_device_id.dart';
import 'package:ledger_zero/services/sync/sync_local_state.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

/// Whether this device can sync with the folder.
enum SyncSetupStatus {
  /// The folder has no manifest: the first device must set a passphrase.
  noFolder,

  /// The folder has a manifest but this device has no (valid) key: the user
  /// must enter the passphrase.
  needsPassphrase,
  ready,
}

/// A manifest already exists (another device set up sync first).
class SyncFolderExistsException implements Exception {
  const SyncFolderExistsException();
  @override
  String toString() => 'SyncFolderExistsException';
}

/// Joining needs a manifest, and the folder has none.
class SyncFolderMissingException implements Exception {
  const SyncFolderMissingException();
  @override
  String toString() => 'SyncFolderMissingException';
}

/// Thrown out of [SyncEngine.sync] when its [SyncCancellation] fired.
class SyncCancelledException implements Exception {
  const SyncCancelledException();
  @override
  String toString() => 'SyncCancelledException';
}

/// Cooperative cancellation of a sync run (app locked, controller
/// disposed). Checked between steps and between files.
class SyncCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void check() {
    if (_cancelled) {
      throw const SyncCancelledException();
    }
  }
}

/// Tunables (tests use small values).
class SyncEngineConfig {
  final int maxChangesPerFile;

  /// Write a snapshot after this many own change files...
  final int snapshotEveryFiles;

  /// ...or when the last snapshot is this old (and there are new files).
  final Duration snapshotEvery;

  /// Own change files covered by an own snapshot older than this are deleted.
  final Duration compactAfter;
  final Duration tombstoneRetention;
  final int maxQuarantineAttempts;
  final int maxConflicts;

  /// KDF parameters for a new manifest.
  final KdfParams Function() kdfParams;

  const SyncEngineConfig({
    this.maxChangesPerFile = 2000,
    this.snapshotEveryFiles = 500,
    this.snapshotEvery = const Duration(days: 7),
    this.compactAfter = const Duration(days: 30),
    this.tombstoneRetention = const Duration(days: 180),
    this.maxQuarantineAttempts = 5,
    this.maxConflicts = 500,
    this.kdfParams = KdfParams.recommended,
  });
}

/// What a sync run did.
class SyncRunReport {
  final SyncSetupStatus setup;
  final int uploaded;
  final int applied;
  final int conflicts;
  final int newlyQuarantined;

  /// A file from a newer app version is waiting (update the app).
  final bool newerSchemaPending;

  /// The folder still contains files of sync format v1 (`*.json.gz`).
  final bool legacyFilesFound;

  /// Devices whose next file is not available yet.
  final int waitingDevices;

  /// A received file carries change timestamps more than
  /// [SyncEngine.clockTolerance] in the future: another device's clock is
  /// off, and its edits win every conflict until it is fixed.
  final bool clockSkewSuspected;

  const SyncRunReport({
    required this.setup,
    this.uploaded = 0,
    this.applied = 0,
    this.conflicts = 0,
    this.newlyQuarantined = 0,
    this.newerSchemaPending = false,
    this.legacyFilesFound = false,
    this.waitingDevices = 0,
    this.clockSkewSuspected = false,
  });
}

/// Sync format v2 orchestration (see docs/SYNC_ARCHITECTURE.md):
///
/// 1. list the folder; check the manifest and this device's key;
/// 2. turn pending local changes into one encrypted change file and upload
///    the outbox (in sequence order);
/// 3. download and apply other devices' files above their high-water mark,
///    each device in sequence order, respecting each file's causal vector,
///    across devices ordered by (newest change, device id); a failing file
///    is quarantined and blocks only its own device;
/// 4. write a snapshot when due and delete own files it covers.
class SyncEngine {
  final AppDatabase _db;
  final SyncTransport transport;

  /// Reconciled with the database's copy at the start of every run
  /// ([SyncDeviceId.reconcile]).
  String deviceId;
  bool _deviceIdReconciled = false;
  final SyncOutbox _outbox;
  final SharedPreferences _prefs;
  final SyncEngineConfig config;
  final DateTime Function() _clock;

  late final SyncSchema _schema = SyncSchema.of(_db);
  late final SyncLocalState _state = SyncLocalState(_db.syncDao);
  late final ChangeGenerator _generator = ChangeGenerator(
    _db,
    _schema,
    _state,
    deviceId,
    maxChangesPerFile: config.maxChangesPerFile,
  );
  late final ChangeApplier _applier = ChangeApplier(_db, _schema, deviceId);

  final Lock _lock = Lock();

  /// Creation time of the folder's manifest, for telling leftovers of an
  /// earlier folder from damaged files.
  DateTime _manifestCreatedAt = DateTime.utc(1970);

  static const String lastSyncKey = 'sync_last_sync_time';

  /// Change timestamps further in the future than this are reported.
  static const Duration clockTolerance = Duration(minutes: 5);

  /// Quarantine reasons (`sync_quarantine.reason`).
  static const String reasonFailed = 'failed';

  /// The file does not authenticate under the sync key (tampered, or an
  /// incomplete upload): retried with backoff, then skipped with a snapshot
  /// request.
  static const String reasonUnreadable = 'unreadable';
  static const String reasonNewerSchema = 'newer_schema';

  /// Written before the current manifest and not readable with its key: a
  /// leftover of an earlier sync folder. Ignored; the user can remove it.
  static const String reasonForeign = 'foreign';

  SyncEngine({
    required this._db,
    required this.transport,
    required this.deviceId,
    required this._outbox,
    required this._prefs,
    this.config = const SyncEngineConfig(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (!SyncFileName.deviceIdPattern.hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'must be a v4 UUID');
    }
  }

  DateTime get _now => _clock().toUtc();

  /// Must run before the generator or applier are first used.
  Future<void> _reconcileDeviceId() async {
    if (_deviceIdReconciled) {
      return;
    }
    final id = await SyncDeviceId.reconcile(_prefs, _state, deviceId);
    if (id != deviceId) {
      Logger.warning('Sync: using the device id stored in the database.');
      deviceId = id;
    }
    _deviceIdReconciled = true;
  }

  // ---------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------

  Future<SyncSetupStatus> setupStatus() async {
    final manifest = await _readManifest(await transport.listFiles());
    if (manifest == null) {
      return SyncSetupStatus.noFolder;
    }
    return await _validKey(manifest) == null
        ? SyncSetupStatus.needsPassphrase
        : SyncSetupStatus.ready;
  }

  /// First device: creates the manifest for [passphrase].
  Future<void> createSyncFolder(String passphrase) {
    return _lock.synchronized(() async {
      await _reconcileDeviceId();
      if (await _readManifest(await transport.listFiles()) != null) {
        throw const SyncFolderExistsException();
      }
      final (manifest, key) = await SyncManifest.create(
        passphrase,
        kdf: config.kdfParams(),
        now: _now,
      );
      await transport.upload(SyncFileName.manifest, manifest.toBytes());
      // Two devices may have raced; everyone uses the canonical manifest.
      final canonical = await _readManifest(await transport.listFiles());
      if (canonical == null || canonical.syncId != manifest.syncId) {
        throw const SyncFolderExistsException();
      }
      await _adoptKey(manifest.syncId, key);
      await _claimSeededRows();
    });
  }

  /// Further devices: derives the key from [passphrase] and checks it.
  /// Throws [WrongSyncPassphraseException].
  Future<void> joinSyncFolder(String passphrase) {
    return _lock.synchronized(() async {
      await _reconcileDeviceId();
      final manifest = await _readManifest(await transport.listFiles());
      if (manifest == null) {
        throw const SyncFolderMissingException();
      }
      final key = await manifest.unlock(passphrase);
      await _adoptKey(manifest.syncId, key);
    });
  }

  /// Forgets the sync key (Disconnect). Progress is kept, so reconnecting
  /// to the same folder continues where it stopped.
  Future<void> forgetKey() => _state.forgetSyncKey();

  Future<void> _adoptKey(String syncId, Uint8List key) async {
    final previous = await _state.syncId();
    await _db.transaction(() async {
      if (previous != syncId) {
        // A different sync set: start from scratch (rows stay).
        await _db.syncDao.clearProgress();
        await _db.syncDao.clearQuarantine();
        await _state.setOwnSequence(0);
        await _state.setOwnSnapshots({});
        await _db.customStatement(
          'UPDATE sync_row_versions SET sequence = 0 '
          'WHERE sequence IS NOT NULL',
        );
      }
      await _state.setSyncKey(syncId, key);
      // Share everything this device has (merged by the conflict rule); a
      // folder that knows this device already gets only what it lacks.
      await _state.setFullUpload(
        previous == syncId ? FullUpload.reshare : FullUpload.everything,
      );
    });
    if (previous != syncId) {
      await _outbox.clear();
    }
  }

  /// The horizon of [FullUpload.reshare]: rows older than this are
  /// re-shared only when newer than the folder's known version.
  DateTime get _reshareHorizon => _now.subtract(config.tombstoneRetention);

  /// The phone that sets up the folder keeps the names of its untouched
  /// default categories: they get a fresh timestamp, so the other phones'
  /// untouched seeds (same ids, same fixed timestamp, names in their own
  /// language) lose deterministically instead of by device-id tiebreak.
  Future<void> _claimSeededRows() async {
    final seed = AppDatabase.seedTimestamp.toIso8601String();
    final now = _now.toIso8601String();
    for (final table in const ['category_groups', 'categories']) {
      await _db.customStatement(
        'UPDATE "$table" SET updated_at = ? WHERE updated_at = ?',
        [now, seed],
      );
    }
  }

  Future<SyncManifest?> _readManifest(List<RemoteFile> files) async {
    final candidates =
        files.where((f) => f.name == SyncFileName.manifest).toList()
          ..sort((a, b) {
            final ta = a.modifiedTime?.microsecondsSinceEpoch ?? 0;
            final tb = b.modifiedTime?.microsecondsSinceEpoch ?? 0;
            return ta != tb ? ta.compareTo(tb) : a.id.compareTo(b.id);
          });
    if (candidates.isEmpty) {
      return null;
    }
    return SyncManifest.fromBytes(await transport.download(candidates.first));
  }

  Future<Uint8List?> _validKey(SyncManifest manifest) async {
    final key = await _state.syncKey();
    final syncId = await _state.syncId();
    if (key == null || syncId != manifest.syncId || !manifest.verifyKey(key)) {
      return null;
    }
    return key;
  }

  // ---------------------------------------------------------------------
  // Sync run
  // ---------------------------------------------------------------------

  Future<SyncRunReport> sync({SyncCancellation? cancellation}) {
    final cancel = cancellation ?? SyncCancellation();
    return _lock.synchronized(() => _run(cancel));
  }

  Future<SyncRunReport> _run(SyncCancellation cancel) async {
    cancel.check();
    await _reconcileDeviceId();
    var listing = await transport.listFiles();
    final manifest = await _readManifest(listing);
    if (manifest == null) {
      return const SyncRunReport(setup: SyncSetupStatus.noFolder);
    }
    final key = await _validKey(manifest);
    if (key == null) {
      if (await _state.syncKey() != null) {
        Logger.warning('Sync key does not match the folder; forgetting it.');
        await _state.forgetSyncKey();
      }
      return const SyncRunReport(setup: SyncSetupStatus.needsPassphrase);
    }

    final remote = _RemoteIndex.from(listing, deviceId);
    final rebootstrap = _prefs.getBool(SyncRebootstrap.prefsKey) ?? false;
    if (rebootstrap) {
      Logger.info('Sync: rebuilding sync state after a restore.');
      await _db.syncDao.clearProgress();
      await _db.syncDao.clearQuarantine();
      // The outbox was emptied by the restore itself; files written since
      // (none while sync is paused) are kept.
      await _state.setOwnSequence(remote.maxSequence(deviceId));
    } else {
      final own = math.max(
        await _state.ownSequence(),
        remote.maxSequence(deviceId),
      );
      await _state.setOwnSequence(own);
      final progress = await _db.syncDao.getProgress();
      if ((progress[deviceId] ?? 0) < own) {
        await _db.syncDao.setProgress(deviceId, own);
      }
    }

    await _db.syncDao.pruneTombstones(
      _now.subtract(config.tombstoneRetention).microsecondsSinceEpoch,
    );
    await _db.syncDao.trimConflicts(config.maxConflicts);

    var uploaded = 0;
    _manifestCreatedAt = manifest.createdAt;
    if (!rebootstrap) {
      cancel.check();
      final fullUpload = await _state.fullUpload();
      await _generator.generate(
        key: key,
        outbox: _outbox,
        fullUpload: fullUpload != FullUpload.none,
        reshareHorizon: fullUpload == FullUpload.reshare
            ? _reshareHorizon
            : null,
        now: _now,
      );
      if (fullUpload != FullUpload.none) {
        await _state.setFullUpload(FullUpload.none);
      }
      uploaded += await _uploadOutbox(cancel);
    }

    cancel.check();
    final applied = await _applyRemote(remote, key, cancel);

    if (rebootstrap) {
      // Rows only the restored database has are shared again; rows that
      // are newer elsewhere already replaced the restored ones. Old rows
      // the folder does not know stay here (their tombstones may be gone).
      cancel.check();
      await _generator.generate(
        key: key,
        outbox: _outbox,
        fullUpload: true,
        reshareHorizon: _reshareHorizon,
        now: _now,
      );
      await _state.setFullUpload(FullUpload.none);
      uploaded += await _uploadOutbox(cancel);
      await _prefs.remove(SyncRebootstrap.prefsKey);
    }

    cancel.check();
    if (uploaded > 0 || applied.applied > 0) {
      listing = await transport.listFiles();
    }
    final index = _RemoteIndex.from(listing, deviceId);
    await _maybeWriteSnapshot(key, cancel, index);
    await _compact(index);

    await _prefs.setString(lastSyncKey, _now.toIso8601String());
    return SyncRunReport(
      setup: SyncSetupStatus.ready,
      uploaded: uploaded,
      applied: applied.applied,
      conflicts: applied.conflicts,
      newlyQuarantined: applied.quarantined,
      newerSchemaPending: applied.newerSchema,
      legacyFilesFound: remote.legacyFound,
      waitingDevices: applied.waiting,
      clockSkewSuspected: applied.futureTimestamps,
    );
  }

  Future<int> _uploadOutbox(SyncCancellation cancel) async {
    var count = 0;
    for (final (name, file) in await _outbox.pending()) {
      cancel.check();
      if (name.deviceId != deviceId) {
        await _outbox.remove(name);
        continue;
      }
      await transport.upload(name.name, await file.readAsBytes());
      await _outbox.remove(name);
      count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------
  // Applying remote files
  // ---------------------------------------------------------------------

  Future<_ApplyStats> _applyRemote(
    _RemoteIndex remote,
    Uint8List key,
    SyncCancellation cancel,
  ) async {
    final stats = _ApplyStats();
    final progress = await _db.syncDao.getProgress();
    final quarantine = {
      for (final q in await _db.syncDao.getQuarantine()) q.filename: q,
    };
    final blocked = <String>{};
    final bytesCache = <String, Uint8List>{};
    final headerCache = <String, SyncFileHeader>{};
    final triedSnapshots = <String>{};

    // A device that has never applied anything from others starts from the
    // newest snapshot (if any) instead of replaying all history.
    final knowsOthers = progress.keys.any((d) => d != deviceId);
    if (!knowsOthers && remote.snapshots.isNotEmpty) {
      await _applySnapshot(
        remote,
        key,
        progress,
        triedSnapshots,
        needs: null,
        stats: stats,
      );
    }
    await _repairSkipped(remote, key, progress, stats);

    var snapshotAttempted = false;
    var gaveUp = false;
    while (true) {
      cancel.check();
      final stalled = <String>{};
      final ready = <(_Candidate, SyncFileHeader)>[];
      for (final device in remote.changes.keys) {
        if (blocked.contains(device)) {
          continue;
        }
        final files = remote.changes[device]!;
        var next = (progress[device] ?? 0) + 1;
        var q = quarantine[SyncFileName.changes(device, next)];
        while (q != null &&
            q.reason == reasonUnreadable &&
            q.attempts >= config.maxQuarantineAttempts) {
          // Still unreadable after every retry: the file will not get
          // better. Continue with the device's next file and ask it for a
          // snapshot, which carries the lost changes.
          Logger.warning(
            'Sync: giving up on ${q.filename}; requesting a snapshot.',
          );
          await _skip(q, quarantine, progress);
          gaveUp = true;
          next = (progress[device] ?? 0) + 1;
          q = quarantine[SyncFileName.changes(device, next)];
        }
        final file = files[next];
        if (file == null) {
          if (files.keys.any((s) => s > next)) {
            stalled.add(device);
          }
          continue;
        }
        final name = SyncFileName.changes(device, next);
        if (q != null &&
            (q.reason == reasonFailed || q.reason == reasonUnreadable) &&
            q.nextAttempt.isAfter(_now)) {
          blocked.add(device);
          continue;
        }
        final candidate = _Candidate(device, next, name, file);
        SyncFileHeader header;
        try {
          header = headerCache[name] ??= await _readHeader(
            candidate,
            bytesCache,
          );
        } on SyncFileFormatException catch (e) {
          await _quarantine(candidate, quarantine, e, stats, reasonFailed);
          blocked.add(device);
          bytesCache.remove(name);
          continue;
        }
        var satisfied = true;
        header.vector.forEach((other, needed) {
          if (other == device) {
            return;
          }
          if ((progress[other] ?? 0) < needed) {
            satisfied = false;
            final available =
                remote.changes[other]?[(progress[other] ?? 0) + 1];
            if (available == null) {
              stalled.add(other);
            }
          }
        });
        if (satisfied) {
          ready.add((candidate, header));
        }
        if (header.maxVersion >
            _now.add(clockTolerance).microsecondsSinceEpoch) {
          stats.futureTimestamps = true;
        }
      }

      if (ready.isEmpty) {
        if (stalled.isNotEmpty && !snapshotAttempted) {
          snapshotAttempted = true;
          final bridged = await _applySnapshot(
            remote,
            key,
            progress,
            triedSnapshots,
            needs: stalled,
            stats: stats,
          );
          if (bridged) {
            continue;
          }
        }
        stats.waiting = stalled.length;
        break;
      }

      ready.sort((a, b) {
        final byVersion = a.$2.maxVersion.compareTo(b.$2.maxVersion);
        return byVersion != 0 ? byVersion : a.$1.device.compareTo(b.$1.device);
      });
      final (candidate, header) = ready.first;
      final ok = await _applyChangeFile(
        candidate,
        header,
        bytesCache.remove(candidate.name)!,
        key,
        progress,
        quarantine,
        stats,
        cancel,
      );
      headerCache.remove(candidate.name);
      if (!ok) {
        blocked.add(candidate.device);
      }
    }
    if (gaveUp) {
      await _repairSkipped(remote, key, progress, stats);
    }
    return stats;
  }

  Future<SyncFileHeader> _readHeader(
    _Candidate candidate,
    Map<String, Uint8List> cache,
  ) async {
    final bytes = cache[candidate.name] ??= await _download(candidate.files);
    return SyncFileCodec.readHeader(bytes);
  }

  /// Downloads one of the listed copies of a file (Drive can hold two files
  /// of the same name after a duplicated upload); prefers the largest.
  Future<Uint8List> _download(List<RemoteFile> copies) {
    final sorted = [...copies]
      ..sort((a, b) => (b.size ?? 0).compareTo(a.size ?? 0));
    return transport.download(sorted.first);
  }

  Future<bool> _applyChangeFile(
    _Candidate candidate,
    SyncFileHeader header,
    Uint8List bytes,
    Uint8List key,
    Map<String, int> progress,
    Map<String, SyncQuarantineData> quarantine,
    _ApplyStats stats,
    SyncCancellation cancel,
  ) async {
    try {
      final file = SyncFileCodec.decode(
        bytes,
        key,
        maxSchemaVersion: _schema.schemaVersion,
      );
      if (file.header.kind != SyncFileKind.changes ||
          file.header.fileName.name != candidate.name) {
        throw const SyncFileFormatException('header does not match name');
      }
      final result = await _applier.apply(
        file,
        now: _now,
        onCommit: () =>
            _db.syncDao.setProgress(candidate.device, candidate.sequence),
      );
      progress[candidate.device] = candidate.sequence;
      if (quarantine.remove(candidate.name) != null) {
        await _db.syncDao.deleteQuarantine(candidate.name);
      }
      stats.applied += result.applied;
      stats.conflicts += result.conflicts;
      return true;
    } on SyncFileNewerSchemaException catch (e) {
      Logger.warning(
        'Sync: ${candidate.name} needs schema '
        '${e.header.schemaVersion}; update the app.',
      );
      stats.newerSchema = true;
      final now = _now;
      final entry = SyncQuarantineCompanion.insert(
        filename: candidate.name,
        deviceId: candidate.device,
        sequence: candidate.sequence,
        reason: reasonNewerSchema,
        error: 'schema ${e.header.schemaVersion}',
        attempts: const Value(0),
        firstSeen: quarantine[candidate.name]?.firstSeen ?? now,
        lastAttempt: now,
        nextAttempt: now,
      );
      await _db.syncDao.putQuarantine(entry);
      return false;
    } on AeadAuthenticationException catch (e) {
      if (_isForeign(header)) {
        // A leftover of an earlier sync folder (written before the current
        // manifest, not readable with its key): nothing to apply, nothing
        // to wait for.
        Logger.warning('Sync: ${candidate.name} is from an old sync folder.');
        await _recordForeign(candidate.name, header);
        await _db.syncDao.setProgress(candidate.device, candidate.sequence);
        progress[candidate.device] = candidate.sequence;
        return true;
      }
      Logger.error('Sync: ${candidate.name} does not authenticate', e);
      await _quarantine(candidate, quarantine, e, stats, reasonUnreadable);
      return false;
    } catch (e, stack) {
      if (cancel.isCancelled) {
        rethrow;
      }
      Logger.error('Sync: could not apply ${candidate.name}', e, stack);
      await _quarantine(candidate, quarantine, e, stats, reasonFailed);
      return false;
    }
  }

  /// Unauthenticated, but good enough to tell leftovers from damage: a
  /// file of the current folder is written after its manifest.
  bool _isForeign(SyncFileHeader header) =>
      header.createdAt.isBefore(_manifestCreatedAt);

  Future<void> _recordForeign(String name, SyncFileHeader header) {
    final now = _now;
    return _db.syncDao.putQuarantine(
      SyncQuarantineCompanion.insert(
        filename: name,
        deviceId: header.deviceId,
        sequence: header.sequence,
        reason: reasonForeign,
        error: 'written before the current sync folder',
        attempts: const Value(0),
        firstSeen: now,
        lastAttempt: now,
        nextAttempt: DateTime.utc(9999),
      ),
    );
  }

  Future<void> _quarantine(
    _Candidate candidate,
    Map<String, SyncQuarantineData> quarantine,
    Object error,
    _ApplyStats stats,
    String reason,
  ) async {
    final now = _now;
    final existing = quarantine[candidate.name];
    final attempts = (existing?.reason == reason ? existing!.attempts : 0) + 1;
    final next = attempts >= config.maxQuarantineAttempts
        ? DateTime.utc(9999)
        : now.add(_backoff(attempts));
    final message = error.toString();
    final entry = SyncQuarantineCompanion.insert(
      filename: candidate.name,
      deviceId: candidate.device,
      sequence: candidate.sequence,
      reason: reason,
      error: message.length > 500 ? message.substring(0, 500) : message,
      attempts: Value(attempts),
      firstSeen: existing?.firstSeen ?? now,
      lastAttempt: now,
      nextAttempt: next,
    );
    await _db.syncDao.putQuarantine(entry);
    quarantine[candidate.name] = SyncQuarantineData(
      filename: candidate.name,
      deviceId: candidate.device,
      sequence: candidate.sequence,
      reason: reason,
      error: entry.error.value,
      attempts: attempts,
      firstSeen: existing?.firstSeen ?? now,
      lastAttempt: now,
      nextAttempt: next,
    );
    if (existing == null) {
      stats.quarantined++;
    }
  }

  /// Advances past the quarantined file [q] and remembers that its device
  /// owes this device a snapshot covering it.
  Future<void> _skip(
    SyncQuarantineData q,
    Map<String, SyncQuarantineData> quarantine,
    Map<String, int> progress,
  ) async {
    await _db.transaction(() async {
      if ((progress[q.deviceId] ?? 0) < q.sequence) {
        await _db.syncDao.setProgress(q.deviceId, q.sequence);
      }
      await _db.syncDao.deleteQuarantine(q.filename);
      final needs = await _state.needsSnapshot();
      needs[q.deviceId] = math.max(needs[q.deviceId] ?? 0, q.sequence);
      await _state.setNeedsSnapshot(needs);
    });
    progress[q.deviceId] = math.max(progress[q.deviceId] ?? 0, q.sequence);
    quarantine.remove(q.filename);
  }

  /// For every device whose file was skipped here: applies that device's
  /// newest snapshot covering the skipped sequence (the rows the skipped
  /// file carried are in it), or writes a request file asking the device
  /// for one.
  Future<void> _repairSkipped(
    _RemoteIndex remote,
    Uint8List key,
    Map<String, int> progress,
    _ApplyStats stats,
  ) async {
    final needs = await _state.needsSnapshot();
    if (needs.isEmpty) {
      return;
    }
    for (final entry in needs.entries.toList()) {
      final device = entry.key;
      final covering = remote.snapshotsNewestFirst.where(
        (s) => s.$1.deviceId == device && s.$1.sequence >= entry.value,
      );
      var repaired = false;
      for (final snapshot in covering) {
        try {
          final bytes = await transport.download(snapshot.$2);
          final file = SyncFileCodec.decode(
            bytes,
            key,
            maxSchemaVersion: _schema.schemaVersion,
          );
          if (file.header.kind != SyncFileKind.snapshot ||
              file.header.fileName.name != snapshot.$1.name) {
            throw const SyncFileFormatException('header does not match name');
          }
          final result = await _applier.apply(
            file,
            now: _now,
            onCommit: () async {
              for (final e in file.header.vector.entries) {
                if (e.value > (progress[e.key] ?? 0)) {
                  await _db.syncDao.setProgress(e.key, e.value);
                }
              }
              needs.remove(device);
              await _state.setNeedsSnapshot(needs);
            },
          );
          for (final e in file.header.vector.entries) {
            progress[e.key] = math.max(progress[e.key] ?? 0, e.value);
          }
          stats.applied += result.applied;
          stats.conflicts += result.conflicts;
          Logger.info('Sync: repaired skipped file with ${snapshot.$1.name}');
          repaired = true;
          break;
        } on SyncFileNewerSchemaException {
          stats.newerSchema = true;
          repaired = true; // wait for the update, do not ask again
          break;
        } catch (e, stack) {
          Logger.error('Sync: snapshot ${snapshot.$1.name} unusable', e, stack);
        }
      }
      if (!repaired) {
        final name = SyncFileName.request(device, deviceId);
        if (!remote.hasRequest(name)) {
          await transport.upload(name, _requestBytes);
          Logger.info('Sync: requested a snapshot from $device');
        }
      }
    }
  }

  static final Uint8List _requestBytes = Uint8List.fromList(
    'ledgerzero-snapshot-request'.codeUnits,
  );

  /// 5 min, 30 min, 3 h, 18 h, ...
  static Duration _backoff(int attempts) =>
      Duration(minutes: 5 * math.pow(6, attempts - 1).toInt());

  /// Applies the newest snapshot that moves [progress] forward for one of
  /// [needs] (any device if null). Returns whether one was applied.
  Future<bool> _applySnapshot(
    _RemoteIndex remote,
    Uint8List key,
    Map<String, int> progress,
    Set<String> tried, {
    required Set<String>? needs,
    required _ApplyStats stats,
  }) async {
    var downloads = 0;
    for (final snapshot in remote.snapshotsNewestFirst) {
      if (downloads >= 5) {
        break;
      }
      if (!tried.add(snapshot.$1.name)) {
        continue;
      }
      downloads++;
      try {
        final bytes = await transport.download(snapshot.$2);
        final header = SyncFileCodec.readHeader(bytes);
        final helps = header.vector.entries.any(
          (e) =>
              (needs == null || needs.contains(e.key)) &&
              e.value > (progress[e.key] ?? 0),
        );
        if (!helps) {
          continue;
        }
        final file = SyncFileCodec.decode(
          bytes,
          key,
          maxSchemaVersion: _schema.schemaVersion,
        );
        if (file.header.kind != SyncFileKind.snapshot ||
            file.header.fileName.name != snapshot.$1.name) {
          throw const SyncFileFormatException('header does not match name');
        }
        final result = await _applier.apply(
          file,
          now: _now,
          onCommit: () async {
            for (final e in file.header.vector.entries) {
              if (e.value > (progress[e.key] ?? 0)) {
                await _db.syncDao.setProgress(e.key, e.value);
              }
            }
          },
        );
        for (final e in file.header.vector.entries) {
          progress[e.key] = math.max(progress[e.key] ?? 0, e.value);
        }
        stats.applied += result.applied;
        stats.conflicts += result.conflicts;
        Logger.info('Sync: applied snapshot ${snapshot.$1.name}');
        return true;
      } on SyncFileNewerSchemaException {
        stats.newerSchema = true;
      } on AeadAuthenticationException catch (e) {
        final header = SyncFileCodec.readHeader(
          await transport.download(snapshot.$2),
        );
        if (_isForeign(header)) {
          await _recordForeign(snapshot.$1.name, header);
        } else {
          Logger.error('Sync: snapshot ${snapshot.$1.name} unusable', e);
        }
      } catch (e, stack) {
        Logger.error('Sync: snapshot ${snapshot.$1.name} unusable', e, stack);
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------
  // Snapshots and compaction
  // ---------------------------------------------------------------------

  Future<void> _maybeWriteSnapshot(
    Uint8List key,
    SyncCancellation cancel,
    _RemoteIndex remote,
  ) async {
    final ownSeq = await _state.ownSequence();
    if (ownSeq == 0) {
      return;
    }
    final requests = remote.requests[deviceId] ?? const <RemoteFile>[];
    final snapshots = await _state.ownSnapshots();
    final lastSeq = snapshots.keys.fold<int>(0, math.max);
    if (ownSeq <= lastSeq && requests.isEmpty) {
      return;
    }
    var since = snapshots[lastSeq] ?? await _state.snapshotClock();
    if (since == null) {
      await _state.setSnapshotClock(_now);
      since = _now;
    }
    // Another device skipped one of this device's files and asked for a
    // snapshot: write one now (it carries the rows the file had).
    final due =
        requests.isNotEmpty ||
        ownSeq - lastSeq >= config.snapshotEveryFiles ||
        !_now.isBefore(since.add(config.snapshotEvery));
    if (!due || await _db.syncDao.pendingCount() > 0) {
      return;
    }
    cancel.check();
    if (ownSeq > lastSeq || !remote.hasSnapshot(deviceId, ownSeq)) {
      final bytes = await writeSnapshotBytes(key, ownSeq);
      await transport.upload(SyncFileName.snapshot(deviceId, ownSeq), bytes);
      snapshots[ownSeq] = _now;
      await _state.setOwnSnapshots(snapshots);
      Logger.info('Sync: wrote snapshot $ownSeq');
    }
    for (final request in requests) {
      await transport.delete(request);
    }
  }

  /// Encrypted snapshot of every synced row and tombstone as of [sequence]
  /// (without the rows of personal accounts, [PersonalRows]).
  Future<Uint8List> writeSnapshotBytes(Uint8List key, int sequence) {
    return _db.transaction(() async {
      final changes = <SyncChange>[];
      final versions = {
        for (final v in await _db.select(_db.syncRowVersions).get())
          (v.syncTable, v.rowId): v,
      };
      final personal = await PersonalRows.load(_db);
      for (final table in SyncSchema.dependencyOrder) {
        final rows = await _db.customSelect('SELECT * FROM "$table"').get();
        for (final r in rows) {
          final row = Map<String, Object?>.of(r.data);
          if (personal.isPrivate(table, row)) {
            continue;
          }
          final id = row['id'] as String;
          final version = SyncSchema.versionOf(row['updated_at']);
          final known = versions[(table, id)];
          changes.add(
            SyncChange(
              table: table,
              id: id,
              deleted: false,
              version: version,
              deviceId:
                  known != null && !known.deleted && known.version == version
                  ? known.deviceId
                  : deviceId,
              row: row,
            ),
          );
        }
      }
      for (final v in versions.values) {
        if (v.deleted && _schema[v.syncTable] != null) {
          changes.add(
            SyncChange(
              table: v.syncTable,
              id: v.rowId,
              deleted: true,
              version: v.version,
              deviceId: v.deviceId,
            ),
          );
        }
      }
      final vector = await _db.syncDao.getProgress();
      vector[deviceId] = sequence;
      final header = SyncFileHeader(
        kind: SyncFileKind.snapshot,
        deviceId: deviceId,
        sequence: sequence,
        schemaVersion: _schema.schemaVersion,
        changeCount: changes.length,
        maxVersion: changes.isEmpty
            ? 0
            : changes.map((c) => c.version).reduce(math.max),
        vector: vector,
        createdAt: _now,
      );
      return SyncFileCodec.encode(header: header, changes: changes, key: key);
    });
  }

  /// Deletes this device's change files covered by its newest snapshot
  /// that is older than [SyncEngineConfig.compactAfter], and its older
  /// snapshots. Never touches other devices' files.
  Future<void> _compact(_RemoteIndex remote) async {
    final snapshots = await _state.ownSnapshots();
    final cutoff = _now.subtract(config.compactAfter);
    final eligible = snapshots.entries
        .where(
          (e) =>
              !e.value.isAfter(cutoff) && remote.hasSnapshot(deviceId, e.key),
        )
        .map((e) => e.key)
        .fold<int>(0, math.max);
    if (eligible == 0) {
      return;
    }
    final own = remote.changes[deviceId] ?? const {};
    for (final entry in own.entries) {
      if (entry.key <= eligible) {
        for (final file in entry.value) {
          await transport.delete(file);
        }
      }
    }
    for (final (name, file) in remote.snapshots) {
      if (name.deviceId == deviceId && name.sequence < eligible) {
        await transport.delete(file);
      }
    }
    snapshots.removeWhere((seq, _) => seq < eligible);
    await _state.setOwnSnapshots(snapshots);
  }

  // ---------------------------------------------------------------------
  // Quarantine actions (Sync settings)
  // ---------------------------------------------------------------------

  /// Allows [filename] (all quarantined files if null) to be retried on the
  /// next run.
  Future<void> retryQuarantined([String? filename]) async {
    final now = _now;
    for (final q in await _db.syncDao.getQuarantine()) {
      if (filename == null || q.filename == filename) {
        await _db.syncDao.putQuarantine(
          q.copyWith(attempts: 0, nextAttempt: now).toCompanion(true),
        );
      }
    }
  }

  /// Gives up on [filename]: its device continues with the next file. The
  /// changes in the skipped file reach this device with that device's next
  /// snapshot, which is requested if none covers the file yet
  /// ([_repairSkipped]).
  Future<void> skipQuarantined(String filename) async {
    final q = await _db.syncDao.getQuarantined(filename);
    if (q == null) {
      return;
    }
    await _skip(q, {}, await _db.syncDao.getProgress());
  }

  /// Deletes the files of an earlier sync folder ([reasonForeign]) from the
  /// folder and forgets them.
  Future<void> removeForeignFiles() {
    return _lock.synchronized(() async {
      final foreign = {
        for (final q in await _db.syncDao.getQuarantine())
          if (q.reason == reasonForeign) q.filename,
      };
      if (foreign.isEmpty) {
        return;
      }
      for (final file in await transport.listFiles()) {
        if (foreign.contains(file.name)) {
          await transport.delete(file);
        }
      }
      for (final name in foreign) {
        await _db.syncDao.deleteQuarantine(name);
      }
    });
  }

  /// Keeps the files of an earlier sync folder but stops listing them.
  Future<void> ignoreForeignFiles() async {
    for (final q in await _db.syncDao.getQuarantine()) {
      if (q.reason == reasonForeign) {
        await _db.syncDao.deleteQuarantine(q.filename);
      }
    }
  }

  /// Local changes not uploaded yet (captured rows plus queued files).
  Future<int> pendingChangeCount() async {
    return await _db.syncDao.pendingCount() + (await _outbox.pending()).length;
  }
}

class _Candidate {
  final String device;
  final int sequence;
  final String name;
  final List<RemoteFile> files;

  _Candidate(this.device, this.sequence, this.name, this.files);
}

class _ApplyStats {
  int applied = 0;
  int conflicts = 0;
  int quarantined = 0;
  int waiting = 0;
  bool newerSchema = false;
  bool futureTimestamps = false;
}

/// Validated view of a folder listing.
class _RemoteIndex {
  /// device -> sequence -> copies (normally one).
  final Map<String, Map<int, List<RemoteFile>>> changes;
  final List<(SyncFileName, RemoteFile)> snapshots;

  /// Snapshot requests: target device -> request files.
  final Map<String, List<RemoteFile>> requests;
  final bool legacyFound;

  _RemoteIndex(this.changes, this.snapshots, this.requests, this.legacyFound);

  factory _RemoteIndex.from(List<RemoteFile> files, String selfId) {
    final changes = <String, Map<int, List<RemoteFile>>>{};
    final snapshots = <(SyncFileName, RemoteFile)>[];
    final requests = <String, List<RemoteFile>>{};
    var legacy = false;
    var rejected = 0;
    for (final file in files) {
      if (file.name == SyncFileName.manifest) {
        continue;
      }
      final name = SyncFileName.tryParse(file.name);
      if (name == null) {
        final request = SyncFileName.tryParseRequest(file.name);
        if (request != null) {
          requests.putIfAbsent(request.target, () => []).add(file);
        } else if (SyncFileName.isLegacy(file.name)) {
          legacy = true;
        } else {
          rejected++;
        }
        continue;
      }
      if (name.kind == SyncFileKind.changes) {
        changes
            .putIfAbsent(name.deviceId, () => {})
            .putIfAbsent(name.sequence, () => [])
            .add(file);
      } else {
        snapshots.add((name, file));
      }
    }
    if (rejected > 0) {
      Logger.warning('Sync: ignored $rejected file(s) with invalid names.');
    }
    return _RemoteIndex(changes, snapshots, requests, legacy);
  }

  bool hasRequest(String name) =>
      requests.values.any((files) => files.any((f) => f.name == name));

  int maxSequence(String device) {
    var max = 0;
    for (final s in changes[device]?.keys ?? const <int>[]) {
      max = math.max(max, s);
    }
    for (final (name, _) in snapshots) {
      if (name.deviceId == device) {
        max = math.max(max, name.sequence);
      }
    }
    return max;
  }

  bool hasSnapshot(String device, int sequence) => snapshots.any(
    (s) => s.$1.deviceId == device && s.$1.sequence == sequence,
  );

  List<(SyncFileName, RemoteFile)> get snapshotsNewestFirst {
    return [...snapshots]..sort((a, b) {
      final ta = a.$2.modifiedTime?.microsecondsSinceEpoch ?? 0;
      final tb = b.$2.modifiedTime?.microsecondsSinceEpoch ?? 0;
      if (ta != tb) {
        return tb.compareTo(ta);
      }
      return b.$1.sequence.compareTo(a.$1.sequence);
    });
  }
}
