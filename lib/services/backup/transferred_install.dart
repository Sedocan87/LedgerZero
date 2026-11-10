import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/services/backup/auto_backup_service.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/sync_device_id.dart';
import 'package:ledger_zero/services/sync/sync_local_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:uuid/uuid.dart';

/// Recognises an install whose data Android moved here from another phone
/// (device-to-device transfer when setting up a new phone, see
/// android/app/src/main/res/xml/data_extraction_rules.xml) and makes it a
/// device of its own.
///
/// Every install writes a random install id twice: into the preferences
/// (which move with the transfer) and into a marker file in Android's
/// no-backup directory (`Context.getNoBackupFilesDir()`, which is never
/// backed up or moved). The preferences carrying an id that the marker does
/// not have means they were made on another phone.
///
/// A moved install would otherwise keep the old phone's sync device id, and
/// if both phones stay in use they would write change files under the same
/// id. So it gets what a restored backup gets (`RestoreService`): no device
/// id (a new one is made at the next sync), an empty change queue and a
/// sync re-bootstrap ([SyncRebootstrap]). It also forgets the Wi-Fi peers
/// of the old phone (the pairing secret stays behind with the secure
/// storage, so Wi-Fi sync asks to pair again) and the old phone's
/// automatic-backup runs (its files stayed there; the next start runs one
/// at once, which finds no password and tells the user so).
///
/// What else moved and is fine: the app lock setting (the lock screen turns
/// it off when the new phone has no screen lock), the automatic-backup
/// switch (its password stayed behind; the Backup screen asks to enter it
/// again), the Google Drive choice (the account is signed in again on the
/// new phone). The card capture store did not move and starts empty; the
/// notification access is granted again in the system settings.
class TransferredInstall {
  TransferredInstall._();

  /// The install id in the preferences.
  static const String prefsKey = 'install_id';

  /// The marker file in the no-backup directory.
  static const String markerName = 'ledgerzero_install_id';

  static const MethodChannel _channel = MethodChannel(
    'com.ledgerzero.app/install',
  );

  /// Android's no-backup directory; null where there is none (tests, other
  /// platforms).
  static Future<Directory?> platformNoBackupDirectory() async {
    try {
      final path = await _channel.invokeMethod<String>('noBackupDirectory');
      return path == null ? null : Directory(path);
    } on MissingPluginException {
      return null;
    }
  }

  /// Whether [prefs] were moved here from another phone. Makes sure both
  /// copies of the install id agree afterwards (a new install writes them
  /// here; an install from before the marker existed adopts its id).
  static Future<bool> detect(
    SharedPreferences prefs,
    Directory noBackupDirectory,
  ) async {
    final marker = File(p.join(noBackupDirectory.path, markerName));
    final markerId = await marker.exists()
        ? (await marker.readAsString()).trim()
        : null;
    final prefsId = prefs.getString(prefsKey);
    if (prefsId != null && prefsId == markerId) {
      return false;
    }
    // No id in the preferences: a new install (or one from before the
    // marker existed), never a moved one. Otherwise the preferences came
    // from a phone whose marker is not here.
    final moved = prefsId != null;
    final id = (!moved && markerId != null && markerId.isNotEmpty)
        ? markerId
        : const Uuid().v4();
    await noBackupDirectory.create(recursive: true);
    await marker.writeAsString(id, flush: true);
    await prefs.setString(prefsKey, id);
    return moved;
  }

  /// Makes the moved install a device of its own (see the class comment).
  /// [database] is the database file, which is not open yet.
  static Future<void> becomeNewDevice(
    SharedPreferences prefs,
    File database,
  ) async {
    // The flag first, like a restore: the next sync run rebuilds the sync
    // state whatever happens below.
    await prefs.setBool(SyncRebootstrap.prefsKey, true);
    await prefs.remove(SyncDeviceId.prefsKey);
    await prefs.remove(LanPeers.prefsKey);
    for (final key in const [
      AutoBackupService.lastSuccessKey,
      AutoBackupService.lastAttemptKey,
      AutoBackupService.lastErrorKey,
    ]) {
      await prefs.remove(key);
    }
    if (!await database.exists()) {
      return;
    }
    final db = sqlite.sqlite3.open(database.path);
    try {
      db.execute('DELETE FROM sync_kv WHERE key = ?', [
        SyncLocalState.deviceIdKey,
      ]);
      db.execute('DELETE FROM pending_sync_changes');
    } on sqlite.SqliteException catch (e) {
      // A damaged database: the lock screen offers the reset.
      Logger.error('Moved install: the database cannot be updated', e);
    } finally {
      db.close();
    }
  }

  /// Start-up: detects a moved install and makes it a new device. Never
  /// fails the start-up.
  static Future<void> checkAtStartup(
    SharedPreferences prefs, {
    required Future<Directory?> Function() noBackupDirectory,
    required Future<File> Function() databaseFile,
  }) async {
    try {
      final dir = await noBackupDirectory();
      if (dir == null || !await detect(prefs, dir)) {
        return;
      }
      Logger.warning('This install was moved from another phone');
      await becomeNewDevice(prefs, await databaseFile());
    } catch (e, stackTrace) {
      Logger.error('Checking for a moved install failed', e, stackTrace);
    }
  }
}
