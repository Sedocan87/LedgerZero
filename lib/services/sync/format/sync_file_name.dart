import 'package:path/path.dart' as p;

/// Kind of a file in the sync folder.
enum SyncFileKind {
  /// `<deviceId>_<sequence>.lzsync`: the changes of one sync run.
  changes,

  /// `<deviceId>_<sequence>.lzsnap`: every synced row as of the device's
  /// change file `<sequence>`, plus the per-device sequences it includes.
  snapshot,
}

/// A validated sync file name.
class SyncFileName {
  final String deviceId;
  final int sequence;
  final SyncFileKind kind;

  const SyncFileName(this.deviceId, this.sequence, this.kind);

  /// Name of the manifest (KDF parameters and key check) in the sync folder.
  static const String manifest = 'ledgerzero-sync-manifest.json';

  /// Device ids are random version-4 UUIDs in lower case.
  static final RegExp deviceIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static final RegExp _pattern = RegExp(
    r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
    r'_([0-9]{12})\.(lzsync|lzsnap)$',
  );

  /// Largest sequence that fits the 12-digit field.
  static const int maxSequence = 999999999999;

  String get name {
    final seq = sequence.toString().padLeft(12, '0');
    final ext = kind == SyncFileKind.changes ? 'lzsync' : 'lzsnap';
    return '${deviceId}_$seq.$ext';
  }

  static String changes(String deviceId, int sequence) =>
      SyncFileName(deviceId, sequence, SyncFileKind.changes).name;

  static String snapshot(String deviceId, int sequence) =>
      SyncFileName(deviceId, sequence, SyncFileKind.snapshot).name;

  /// Parses a name listed by a transport. Returns null for anything that is
  /// not exactly a sync file name: other files, names with directories,
  /// `..`, separators or any other character. Remote names are untrusted
  /// and never reach a local path unless they pass this check.
  static SyncFileName? tryParse(String remoteName) {
    if (remoteName.isEmpty || remoteName.length > 64) {
      return null;
    }
    if (p.basename(remoteName) != remoteName ||
        p.posix.basename(remoteName) != remoteName ||
        p.windows.basename(remoteName) != remoteName) {
      return null;
    }
    final match = _pattern.firstMatch(remoteName);
    if (match == null) {
      return null;
    }
    final sequence = int.parse(match.group(2)!);
    if (sequence < 1) {
      return null;
    }
    return SyncFileName(
      match.group(1)!,
      sequence,
      match.group(3) == 'lzsync' ? SyncFileKind.changes : SyncFileKind.snapshot,
    );
  }

  /// Files written by sync format v1 (plaintext `.json.gz` deltas). They are
  /// ignored; Sync settings tells the user they can be deleted.
  static bool isLegacy(String remoteName) => remoteName.endsWith('.json.gz');

  static final RegExp _requestPattern = RegExp(
    r'^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
    r'_req_([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
    r'\.lzsreq$',
  );

  /// `<target>_req_<requester>.lzsreq`: [requester] asks [target] to write
  /// a snapshot (after it skipped one of [target]'s files; see
  /// docs/SYNC_ARCHITECTURE.md "Quarantine"). The file carries no data.
  static String request(String target, String requester) =>
      '${target}_req_$requester.lzsreq';

  /// Parses a snapshot request name (same checks as [tryParse]).
  static ({String target, String requester})? tryParseRequest(
    String remoteName,
  ) {
    if (remoteName.isEmpty || remoteName.length > 96) {
      return null;
    }
    if (p.basename(remoteName) != remoteName ||
        p.posix.basename(remoteName) != remoteName ||
        p.windows.basename(remoteName) != remoteName) {
      return null;
    }
    final match = _requestPattern.firstMatch(remoteName);
    if (match == null) {
      return null;
    }
    return (target: match.group(1)!, requester: match.group(2)!);
  }

  @override
  bool operator ==(Object other) =>
      other is SyncFileName &&
      other.deviceId == deviceId &&
      other.sequence == sequence &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(deviceId, sequence, kind);

  @override
  String toString() => name;
}
