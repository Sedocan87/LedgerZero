import 'dart:typed_data';

/// A file in the remote sync folder.
class RemoteFile {
  /// Name as listed by the provider. Untrusted: validate with
  /// `SyncFileName.tryParse` before using it for anything.
  final String name;

  /// Provider id (with Wi-Fi sync: the file name).
  final String id;
  final int? size;
  final DateTime? modifiedTime;

  const RemoteFile(this.name, this.id, {this.size, this.modifiedTime});

  @override
  String toString() => 'RemoteFile($name)';
}

/// Storage for the sync folder (Wi-Fi sync's folder on this phone, a fake
/// in tests).
/// Implementations retry transient errors themselves and throw a
/// `SyncException` otherwise.
abstract class SyncTransport {
  /// Stable identifier (e.g. 'local_wifi').
  String get name;

  /// Every file in the sync folder (all pages).
  Future<List<RemoteFile>> listFiles();

  /// The complete content of [file]. Completes only when the whole file is
  /// available locally.
  Future<Uint8List> download(RemoteFile file);

  /// Stores [bytes] as [name]. Idempotent: retrying after a timeout never
  /// creates a second file of the same name. If a file of that name exists
  /// with the same size it is kept; otherwise its content is replaced —
  /// except the manifest, which is never replaced once it exists (two
  /// devices racing to create the folder must both end up with the earlier
  /// one; an overwritten manifest would orphan every file in the folder).
  Future<void> upload(String name, Uint8List bytes);

  /// Deletes [file]. Deleting a file that no longer exists succeeds.
  Future<void> delete(RemoteFile file);

  /// Releases cached clients.
  Future<void> dispose();
}
