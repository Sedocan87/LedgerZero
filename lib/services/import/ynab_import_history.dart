import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which YNAB exports were imported (by content fingerprint), so
/// a second import of the same file can warn before duplicating every
/// transaction.
abstract class YnabImportHistory {
  /// When the export with [fingerprint] was imported, or `null`.
  Future<DateTime?> importedAt(String fingerprint);

  /// Records that the export with [fingerprint] was imported at [at].
  Future<void> record(String fingerprint, DateTime at);
}

/// Kept in SharedPreferences (device-local, like other import state); the
/// last [maxEntries] imports are remembered.
class SharedPreferencesYnabImportHistory implements YnabImportHistory {
  SharedPreferencesYnabImportHistory(this._prefs);

  static const key = 'ynab_import_history';
  static const maxEntries = 50;

  final SharedPreferences _prefs;

  List<Map<String, dynamic>> _entries() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is Map<String, dynamic>) e,
        ];
      }
    } catch (e) {
      Logger.warning('YNAB import history unreadable, starting over: $e');
    }
    return [];
  }

  @override
  Future<DateTime?> importedAt(String fingerprint) async {
    for (final entry in _entries()) {
      if (entry['fingerprint'] == fingerprint) {
        return DateTime.tryParse(entry['importedAt']?.toString() ?? '');
      }
    }
    return null;
  }

  @override
  Future<void> record(String fingerprint, DateTime at) async {
    final entries = _entries()
      ..removeWhere((e) => e['fingerprint'] == fingerprint)
      ..add({'fingerprint': fingerprint, 'importedAt': at.toIso8601String()});
    while (entries.length > maxEntries) {
      entries.removeAt(0);
    }
    await _prefs.setString(key, jsonEncode(entries));
  }
}

/// For tests and containers without preferences.
class InMemoryYnabImportHistory implements YnabImportHistory {
  final Map<String, DateTime> _imports = {};

  @override
  Future<DateTime?> importedAt(String fingerprint) async =>
      _imports[fingerprint];

  @override
  Future<void> record(String fingerprint, DateTime at) async {
    _imports[fingerprint] = at;
  }
}

final ynabImportHistoryProvider = Provider<YnabImportHistory>((ref) {
  return SharedPreferencesYnabImportHistory(
    ref.watch(sharedPreferencesProvider),
  );
});
