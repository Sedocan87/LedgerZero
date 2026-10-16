/// One row-level change in a change file or snapshot.
///
/// [version] is the row's `updated_at` in microseconds since the epoch (UTC)
/// for upserts, or the time of the delete for tombstones. Together with
/// [deviceId] (the device that wrote this version) it decides conflicts:
/// the greater `(version, deviceId)` wins.
class SyncChange {
  final String table;
  final String id;
  final bool deleted;
  final int version;
  final String deviceId;

  /// Full row (column name -> SQL value) for upserts; null for deletes.
  final Map<String, Object?>? row;

  const SyncChange({
    required this.table,
    required this.id,
    required this.deleted,
    required this.version,
    required this.deviceId,
    this.row,
  });

  Map<String, Object?> toJson() => {
    't': table,
    'id': id,
    'op': deleted ? 'd' : 'u',
    'v': version,
    'dev': deviceId,
    if (!deleted) 'row': row,
  };

  factory SyncChange.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('change is not an object');
    }
    final table = json['t'];
    final id = json['id'];
    final op = json['op'];
    final version = json['v'];
    final device = json['dev'];
    if (table is! String ||
        id is! String ||
        id.isEmpty ||
        (op != 'u' && op != 'd') ||
        version is! int ||
        version < 0 ||
        device is! String ||
        device.isEmpty) {
      throw const FormatException('malformed change');
    }
    final deleted = op == 'd';
    Map<String, Object?>? row;
    if (!deleted) {
      final raw = json['row'];
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('upsert without row');
      }
      for (final value in raw.values) {
        if (value != null && value is! String && value is! num) {
          throw const FormatException('unsupported column value');
        }
      }
      if (raw['id'] != id) {
        throw const FormatException('row id does not match change id');
      }
      row = Map<String, Object?>.from(raw);
    }
    return SyncChange(
      table: table,
      id: id,
      deleted: deleted,
      version: version,
      deviceId: device,
      row: row,
    );
  }
}
