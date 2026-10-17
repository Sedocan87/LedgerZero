import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A paired phone as last seen on the network.
class LanPeer {
  const LanPeer({
    required this.deviceId,
    required this.name,
    this.host,
    this.port,
    this.lastSeen,
    this.lastSync,
  });

  final String deviceId;
  final String name;

  /// Last known address (from discovery, a request or the pairing code).
  final String? host;
  final int? port;

  /// Last discovery beacon or request from it.
  final DateTime? lastSeen;

  /// Last successful exchange of files with it.
  final DateTime? lastSync;

  bool get hasAddress => host != null && port != null;

  LanPeer copyWith({
    String? name,
    String? host,
    int? port,
    DateTime? lastSeen,
    DateTime? lastSync,
  }) => LanPeer(
    deviceId: deviceId,
    name: name ?? this.name,
    host: host ?? this.host,
    port: port ?? this.port,
    lastSeen: lastSeen ?? this.lastSeen,
    lastSync: lastSync ?? this.lastSync,
  );

  Map<String, Object?> toJson() => {
    'd': deviceId,
    'n': name,
    'h': host,
    'p': port,
    's': lastSeen?.toIso8601String(),
    'y': lastSync?.toIso8601String(),
  };

  factory LanPeer.fromJson(Map<String, Object?> json) => LanPeer(
    deviceId: json['d'] as String,
    name: json['n'] as String? ?? '',
    host: json['h'] as String?,
    port: json['p'] as int?,
    lastSeen: DateTime.tryParse(json['s'] as String? ?? ''),
    lastSync: DateTime.tryParse(json['y'] as String? ?? ''),
  );
}

/// The paired phones (no secrets), kept in SharedPreferences.
class LanPeers {
  LanPeers(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  final _peers = <String, LanPeer>{};
  final _changes = StreamController<List<LanPeer>>.broadcast();

  static const String prefsKey = 'lan_sync_peers';

  List<LanPeer> get all =>
      _peers.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Stream<List<LanPeer>> get changes => _changes.stream;

  LanPeer? operator [](String deviceId) => _peers[deviceId];

  void _load() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null) {
      return;
    }
    try {
      for (final json in jsonDecode(raw) as List) {
        final peer = LanPeer.fromJson(json as Map<String, Object?>);
        _peers[peer.deviceId] = peer;
      }
    } catch (_) {
      // Damaged entry: start without peers; discovery finds them again.
    }
  }

  /// Adds [peer] or merges it into the known entry (non-null fields win).
  Future<void> upsert(LanPeer peer) async {
    final known = _peers[peer.deviceId];
    _peers[peer.deviceId] = known == null
        ? peer
        : known.copyWith(
            name: peer.name.isEmpty ? null : peer.name,
            host: peer.host,
            port: peer.port,
            lastSeen: peer.lastSeen,
            lastSync: peer.lastSync,
          );
    await _save();
  }

  Future<void> clear() async {
    _peers.clear();
    await _prefs.remove(prefsKey);
    _changes.add(all);
  }

  Future<void> _save() async {
    await _prefs.setString(
      prefsKey,
      jsonEncode([for (final p in _peers.values) p.toJson()]),
    );
    _changes.add(all);
  }

  Future<void> dispose() => _changes.close();
}
