import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// This installation's sync device id: a random version-4 UUID created once
/// and kept in SharedPreferences (not in the database, so restoring a
/// backup on another phone does not clone the id). Platform ids are not
/// used: Android's `Build.ID` is the same on every device with the same
/// firmware.
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
}
