import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// After a restore the local history no longer matches what other devices
/// have seen, so the device must rebuild its sync state.
///
/// [markRequired] sets [prefsKey] before the database files are swapped
/// (sync is paused meanwhile); [discardOutbox] deletes the queued, not yet
/// uploaded change files of the replaced database once the swap succeeded.
/// (The restored database's `pending_sync_changes` table is emptied by the
/// restore itself.) The next sync run (`SyncEngine`) sees the flag, forgets
/// the per-device high-water marks, applies the newest snapshot and every
/// later change file under the normal conflict rule — so rows changed
/// elsewhere after the backup win only if they are newer — then re-shares
/// the local rows and clears the flag. See docs/SYNC_ARCHITECTURE.md
/// ("Restore").
class SyncRebootstrap {
  static const String prefsKey = 'sync_rebootstrap_required';

  final SharedPreferences _prefs;
  final SyncOutbox? _outbox;

  SyncRebootstrap(this._prefs, [this._outbox]);

  bool get isRequired => _prefs.getBool(prefsKey) ?? false;

  Future<void> markRequired() => _prefs.setBool(prefsKey, true);

  /// Deletes the change files queued by the database that was replaced.
  Future<void> discardOutbox() async {
    try {
      await _outbox?.clear();
    } catch (_) {}
  }

  Future<void> clear() => _prefs.remove(prefsKey);
}
