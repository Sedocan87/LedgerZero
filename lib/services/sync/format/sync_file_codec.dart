import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'dart:typed_data';

import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/sync/format/sync_change.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';

/// A file that is not a valid sync format v2 file (truncated, wrong magic,
/// malformed header or body).
class SyncFileFormatException implements Exception {
  final String message;
  const SyncFileFormatException(this.message);

  @override
  String toString() => 'SyncFileFormatException: $message';
}

/// An authentic file written by a newer app version (its schema version is
/// higher than this app's). It is not applied until the app is updated.
class SyncFileNewerSchemaException implements Exception {
  final SyncFileHeader header;
  const SyncFileNewerSchemaException(this.header);

  @override
  String toString() =>
      'SyncFileNewerSchemaException: schema ${header.schemaVersion}';
}

/// Authenticated, unencrypted metadata of a change file or snapshot.
///
/// It is the AES-GCM associated data, so it cannot be changed without the
/// decryption failing. It lets the engine schedule files (sequence, causal
/// vector, newest timestamp, schema version) before decrypting them.
class SyncFileHeader {
  static const int currentFormat = 2;

  final int format;
  final SyncFileKind kind;
  final String deviceId;
  final int sequence;

  /// `AppDatabase.schemaVersion` of the writer.
  final int schemaVersion;
  final int changeCount;

  /// Largest change version in the file (µs since epoch, UTC).
  final int maxVersion;

  /// For change files: the writer's high-water marks (device -> last applied
  /// sequence) when it wrote the file; the file must be applied after those.
  /// For snapshots: the sequences whose effects the snapshot contains.
  final Map<String, int> vector;
  final DateTime createdAt;

  const SyncFileHeader({
    this.format = currentFormat,
    required this.kind,
    required this.deviceId,
    required this.sequence,
    required this.schemaVersion,
    required this.changeCount,
    required this.maxVersion,
    required this.vector,
    required this.createdAt,
  });

  SyncFileName get fileName => SyncFileName(deviceId, sequence, kind);

  Map<String, Object?> toJson() => {
    'format': format,
    'kind': kind == SyncFileKind.changes ? 'changes' : 'snapshot',
    'device': deviceId,
    'seq': sequence,
    'schema': schemaVersion,
    'count': changeCount,
    'maxVersion': maxVersion,
    'vector': vector,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory SyncFileHeader.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const SyncFileFormatException('header is not an object');
    }
    try {
      final kind = switch (json['kind']) {
        'changes' => SyncFileKind.changes,
        'snapshot' => SyncFileKind.snapshot,
        _ => throw const SyncFileFormatException('unknown kind'),
      };
      final device = json['device'] as String;
      if (!SyncFileName.deviceIdPattern.hasMatch(device)) {
        throw const SyncFileFormatException('invalid device id');
      }
      final vectorJson = json['vector'] as Map<String, dynamic>;
      final vector = <String, int>{};
      vectorJson.forEach((key, value) {
        if (!SyncFileName.deviceIdPattern.hasMatch(key) ||
            value is! int ||
            value < 0) {
          throw const SyncFileFormatException('invalid vector');
        }
        vector[key] = value;
      });
      final header = SyncFileHeader(
        format: json['format'] as int,
        kind: kind,
        deviceId: device,
        sequence: json['seq'] as int,
        schemaVersion: json['schema'] as int,
        changeCount: json['count'] as int,
        maxVersion: json['maxVersion'] as int,
        vector: vector,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      );
      if (header.sequence < 1 ||
          header.sequence > SyncFileName.maxSequence ||
          header.changeCount < 0 ||
          header.schemaVersion < 1) {
        throw const SyncFileFormatException('header values out of range');
      }
      return header;
    } on SyncFileFormatException {
      rethrow;
    } catch (_) {
      throw const SyncFileFormatException('malformed header');
    }
  }
}

/// A decrypted file.
class SyncFile {
  final SyncFileHeader header;
  final List<SyncChange> changes;

  const SyncFile(this.header, this.changes);
}

/// Sync format v2 container:
///
/// ```
/// "LZS2" | u32 big-endian header length | header JSON (UTF-8)
///        | 12-byte nonce | AES-256-GCM(gzip(body JSON)) with 16-byte tag
/// ```
///
/// Associated data = everything before the nonce (magic, length, header).
/// The body is `{"changes": [SyncChange...]}`.
class SyncFileCodec {
  SyncFileCodec._();

  static const List<int> magic = [0x4C, 0x5A, 0x53, 0x32]; // "LZS2"
  static const int _maxHeaderLength = 1 << 20;

  /// Decompressed body limit (protects against a hostile but authentic
  /// file; unauthenticated data is never decompressed).
  static const int maxBodyBytes = 512 << 20;

  static Uint8List encode({
    required SyncFileHeader header,
    required List<SyncChange> changes,
    required Uint8List key,
  }) {
    final headerBytes = utf8.encode(jsonEncode(header.toJson()));
    final prefix = BytesBuilder(copy: false)
      ..add(magic)
      ..add(_u32(headerBytes.length))
      ..add(headerBytes);
    final aad = prefix.toBytes();
    final body = utf8.encode(
      jsonEncode({'changes': changes.map((c) => c.toJson()).toList()}),
    );
    final compressed = Uint8List.fromList(GZipCodec().encode(body));
    final nonce = AesGcm.randomNonce();
    final ciphertext = AesGcm.encrypt(
      key: key,
      nonce: nonce,
      plaintext: compressed,
      aad: aad,
    );
    return (BytesBuilder(copy: false)
          ..add(aad)
          ..add(nonce)
          ..add(ciphertext))
        .toBytes();
  }

  /// Reads the header without authenticating it (for scheduling only;
  /// [decode] authenticates it).
  static SyncFileHeader readHeader(Uint8List bytes) =>
      SyncFileHeader.fromJson(_split(bytes).headerJson);

  /// Decrypts and parses [bytes]. Throws [AeadAuthenticationException] for a
  /// wrong key or tampered data, [SyncFileFormatException] for anything
  /// malformed, and [SyncFileNewerSchemaException] (after authentication)
  /// when the writer's schema is newer than [maxSchemaVersion].
  static SyncFile decode(
    Uint8List bytes,
    Uint8List key, {
    int? maxSchemaVersion,
  }) {
    final parts = _split(bytes);
    final header = SyncFileHeader.fromJson(parts.headerJson);
    if (header.format != SyncFileHeader.currentFormat) {
      throw SyncFileFormatException('unsupported format ${header.format}');
    }
    final plain = AesGcm.decrypt(
      key: key,
      nonce: parts.nonce,
      ciphertext: parts.ciphertext,
      aad: parts.aad,
    );
    if (maxSchemaVersion != null && header.schemaVersion > maxSchemaVersion) {
      throw SyncFileNewerSchemaException(header);
    }
    final List<int> body;
    try {
      body = GZipCodec().decode(plain);
    } catch (_) {
      throw const SyncFileFormatException('body is not gzip');
    }
    if (body.length > maxBodyBytes) {
      throw const SyncFileFormatException('body too large');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(body));
    } catch (_) {
      throw const SyncFileFormatException('body is not JSON');
    }
    if (json is! Map<String, dynamic> || json['changes'] is! List) {
      throw const SyncFileFormatException('body has no changes');
    }
    final List<SyncChange> changes;
    try {
      changes = [
        for (final c in json['changes'] as List) SyncChange.fromJson(c),
      ];
    } on FormatException catch (e) {
      throw SyncFileFormatException(e.message);
    }
    if (changes.length != header.changeCount) {
      throw const SyncFileFormatException('change count mismatch');
    }
    return SyncFile(header, changes);
  }

  static _Parts _split(Uint8List bytes) {
    if (bytes.length < 8) {
      throw const SyncFileFormatException('file too short');
    }
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) {
        throw const SyncFileFormatException('not a sync file');
      }
    }
    final length = ByteData.sublistView(bytes, 4, 8).getUint32(0);
    if (length == 0 || length > _maxHeaderLength) {
      throw const SyncFileFormatException('invalid header length');
    }
    final headerEnd = 8 + length;
    if (bytes.length < headerEnd + AesGcm.nonceLength + AesGcm.tagLength) {
      throw const SyncFileFormatException('file truncated');
    }
    final Object? headerJson;
    try {
      headerJson = jsonDecode(utf8.decode(bytes.sublist(8, headerEnd)));
    } catch (_) {
      throw const SyncFileFormatException('header is not JSON');
    }
    return _Parts(
      aad: Uint8List.sublistView(bytes, 0, headerEnd),
      headerJson: headerJson,
      nonce: Uint8List.sublistView(
        bytes,
        headerEnd,
        headerEnd + AesGcm.nonceLength,
      ),
      ciphertext: Uint8List.sublistView(bytes, headerEnd + AesGcm.nonceLength),
    );
  }

  static Uint8List _u32(int value) {
    final data = ByteData(4)..setUint32(0, value);
    return data.buffer.asUint8List();
  }
}

class _Parts {
  final Uint8List aad;
  final Object? headerJson;
  final Uint8List nonce;
  final Uint8List ciphertext;

  const _Parts({
    required this.aad,
    required this.headerJson,
    required this.nonce,
    required this.ciphertext,
  });
}
