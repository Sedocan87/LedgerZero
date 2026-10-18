import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/sync_local_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// This installation's sync device id: a random version-4 UUID created once
/// and kept in SharedPreferences, with a copy in the encrypted database
/// (`sync_kv.device_id`) so that lost preferences do not mint a new id and
/// orphan the files queued under the old one. Platform ids are not used:
/// Android's `Build.ID` is the same on every device with the same firmware.
///
/// A restored backup never carries an id: the restore strips it, so a
/// backup restored on another phone does not clone the first phone's id.
class SyncDeviceId {
  SyncDeviceId._();

  static const String prefsKey = 'sync_device_id';

  static String of(SharedPreferences prefs) {
    final existing = prefs.getString(prefsKey);
    if (existing != null && SyncFileName.deviceIdPattern.hasMatch(existing)) {
      return existing;
    }
    final id = const Uuid().v4().toLowerCase();
    prefs.setString(prefsKey, id);
    return id;
  }

  /// The id to use with the open database: the database's copy wins (the
  /// preferences are updated to it); without one, [current] (the id from
  /// the preferences) is stored in the database.
  static Future<String> reconcile(
    SharedPreferences prefs,
    SyncLocalState state,
    String current,
  ) async {
    final stored = await state.deviceId();
    final id = stored != null && SyncFileName.deviceIdPattern.hasMatch(stored)
        ? stored
        : current;
    if (prefs.getString(prefsKey) != id) {
      await prefs.setString(prefsKey, id);
    }
    if (stored != id) {
      await state.setDeviceId(id);
    }
    return id;
  }
}
