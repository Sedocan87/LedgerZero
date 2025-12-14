import 'dart:io';

class RemoteFile {
  final String name;
  final String id;
  // Optional metadata map for different transports (e.g. 'size', 'modifiedTime', 'url')
  final Map<String, dynamic>? metadata;

  RemoteFile(this.name, this.id, {this.metadata});
}

abstract class SyncTransport {
  /// Unique identifier for this transport (e.g., 'google_drive', 'local_network')
  String get name;

  /// User-friendly name
  String get displayName;

  /// Initialize any necessary resources (e.g. login, server start)
  Future<void> initialize();

  /// Dispose resources
  Future<void> dispose();

  /// List available delta files on the remote/peer
  Future<List<RemoteFile>> listDeltas();

  /// Download a specific delta file
  Future<File> downloadDelta(RemoteFile remoteFile, String savePath);

  /// Upload a local delta file
  /// Returns the ID/Path of the uploaded file on success
  Future<String?> uploadDelta(File localFile, String filename);

  /// Delete a remote file (optional/maintenance)
  Future<void> deleteFile(String fileId);
}
