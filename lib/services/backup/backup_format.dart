import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';

/// A backup could not be created or read.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

/// Wrong backup password, or the file was modified or truncated.
class BackupAuthenticationException extends BackupException {
  const BackupAuthenticationException()
    : super('Wrong password, or the backup file is damaged');
}

/// Not a LedgerZero backup (or an unsupported layout).
class BackupFormatException extends BackupException {
  const BackupFormatException(super.message);
}

/// Made by a newer app version (format or schema).
class BackupTooNewException extends BackupException {
  const BackupTooNewException()
    : super('This backup was made by a newer version of LedgerZero');
}

class BackupInfo {
  final int formatVersion;

  /// Database schema version recorded in the header (v2 only).
  final int? schemaVersion;
  final DateTime? createdAt;

  const BackupInfo(this.formatVersion, {this.schemaVersion, this.createdAt});
}

/// The `.lzbk` backup file format.
///
/// ## Version 2 (written by this version)
///
/// ```
/// "LZBK" | 0x02 | header length (u32 BE) | header (UTF-8 JSON)
/// then records: ciphertext length (u32 BE) | AES-256-GCM ciphertext + tag
/// ```
///
/// The header holds the KDF (algorithm, parameters, salt), a 7-byte random
/// nonce prefix, the chunk size, the compression (`gzip`), the database
/// schema version and the creation time (UTC). The key is
/// `KDF(backup password)`; every backup has a fresh salt, so a fresh key.
///
/// The plaintext (a gzip stream of a plain SQLite database) is cut into
/// chunks of `chunk_size` bytes. Chunk *i* is encrypted with nonce
/// `prefix(7) || i (u32 BE) || last (1 byte: 1 for the final chunk)` and the
/// complete header bytes as associated data (the STREAM construction). Any
/// change to the header, reordering, truncation or appended data fails
/// authentication. Memory use is bounded by the chunk size.
///
/// ## Version 1 (read only)
///
/// `salt (32) | IV (12) | AES-256-GCM(gzip(database)) + tag`, key =
/// PBKDF2-HMAC-SHA256(password, salt, 100,000 iterations).
class BackupFormat {
  BackupFormat._();

  static final Uint8List magic = Uint8List.fromList(ascii.encode('LZBK'));
  static const int currentVersion = 2;
  static const int defaultChunkSize = 1 << 20;
  static const int _maxHeaderLength = 64 * 1024;
  static const int _noncePrefixLength = 7;

  /// Encrypts the database file [plaintext] into [output].
  static Future<void> encryptFile({
    required File plaintext,
    required File output,
    required String password,
    required int schemaVersion,
    KdfParams? kdf,
    int chunkSize = defaultChunkSize,
    DateTime? createdAt,
  }) async {
    final params = kdf ?? KdfParams.recommended();
    final noncePrefix = secureRandomBytes(_noncePrefixLength);
    final headerJson = utf8.encode(
      jsonEncode({
        'format': 'ledgerzero-backup',
        'kdf': params.toJson(),
        'cipher': 'aes-256-gcm-stream',
        'nonce_prefix': base64.encode(noncePrefix),
        'chunk_size': chunkSize,
        'compression': 'gzip',
        'schema_version': schemaVersion,
        'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      }),
    );
    final header = BytesBuilder()
      ..add(magic)
      ..addByte(currentVersion)
      ..add(_u32(headerJson.length))
      ..add(headerJson);
    final headerBytes = header.toBytes();

    final key = await deriveKey(password, params);
    final sink = output.openWrite();
    try {
      sink.add(headerBytes);
      var index = 0;
      Uint8List? pending;
      final buffer = BytesBuilder(copy: false);

      void writeChunk(Uint8List chunk, {required bool last}) {
        final ciphertext = AesGcm.encrypt(
          key: key,
          nonce: _nonce(noncePrefix, index, last: last),
          plaintext: chunk,
          aad: headerBytes,
        );
        sink
          ..add(_u32(ciphertext.length))
          ..add(ciphertext);
        index++;
      }

      await for (final data in plaintext.openRead().transform(gzip.encoder)) {
        buffer.add(data);
        while (buffer.length >= chunkSize) {
          final all = buffer.takeBytes();
          final chunk = Uint8List.sublistView(all, 0, chunkSize);
          if (all.length > chunkSize) {
            buffer.add(Uint8List.sublistView(all, chunkSize));
          }
          if (pending != null) {
            writeChunk(pending, last: false);
          }
          pending = Uint8List.fromList(chunk);
        }
        await sink.flush();
      }
      final rest = buffer.takeBytes();
      if (rest.isNotEmpty) {
        if (pending != null) {
          writeChunk(pending, last: false);
        }
        writeChunk(rest, last: true);
      } else {
        writeChunk(pending ?? Uint8List(0), last: true);
      }
      await sink.flush();
    } finally {
      await sink.close();
      zeroBytes(key);
    }
  }

  /// Decrypts [input] (v2 or v1) into the plain database file [output].
  static Future<BackupInfo> decryptFile({
    required File input,
    required File output,
    required String password,
  }) async {
    final raf = await input.open();
    try {
      final length = await raf.length();
      final start = await raf.read(5);
      if (start.length == 5 && _startsWithMagic(start)) {
        final version = start[4];
        if (version > currentVersion) {
          throw const BackupTooNewException();
        }
        if (version != 2) {
          throw const BackupFormatException('Unsupported backup version');
        }
        return await _decryptV2(raf, length, output, password);
      }
    } finally {
      await raf.close();
    }
    return _decryptV1(input, output, password);
  }

  static Future<BackupInfo> _decryptV2(
    RandomAccessFile raf,
    int length,
    File output,
    String password,
  ) async {
    final headerLength = _readU32(await raf.read(4));
    if (headerLength <= 0 || headerLength > _maxHeaderLength) {
      throw const BackupFormatException('Invalid backup header');
    }
    final headerJsonBytes = await raf.read(headerLength);
    if (headerJsonBytes.length != headerLength) {
      throw const BackupFormatException('Truncated backup header');
    }
    final headerBytes =
        (BytesBuilder()
              ..add(magic)
              ..addByte(2)
              ..add(_u32(headerLength))
              ..add(headerJsonBytes))
            .toBytes();

    final Map<String, dynamic> header;
    final KdfParams params;
    final Uint8List noncePrefix;
    final int chunkSize;
    try {
      header = jsonDecode(utf8.decode(headerJsonBytes)) as Map<String, dynamic>;
      if (header['format'] != 'ledgerzero-backup' ||
          header['cipher'] != 'aes-256-gcm-stream' ||
          header['compression'] != 'gzip') {
        throw const BackupFormatException('Unsupported backup header');
      }
      params = KdfParams.fromJson(header['kdf'] as Map<String, dynamic>);
      noncePrefix = base64.decode(header['nonce_prefix'] as String);
      chunkSize = header['chunk_size'] as int;
      if (noncePrefix.length != _noncePrefixLength ||
          chunkSize <= 0 ||
          chunkSize > 64 * defaultChunkSize) {
        throw const BackupFormatException('Invalid backup header');
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException('Invalid backup header');
    }

    final key = await deriveKey(password, params);
    try {
      Stream<List<int>> chunks() async* {
        var index = 0;
        var sawLast = false;
        while (await raf.position() < length) {
          if (sawLast) {
            throw const BackupAuthenticationException();
          }
          final lenBytes = await raf.read(4);
          if (lenBytes.length != 4) {
            throw const BackupAuthenticationException();
          }
          final ctLength = _readU32(lenBytes);
          if (ctLength < AesGcm.tagLength ||
              ctLength > chunkSize + AesGcm.tagLength) {
            throw const BackupAuthenticationException();
          }
          final ciphertext = await raf.read(ctLength);
          if (ciphertext.length != ctLength) {
            throw const BackupAuthenticationException();
          }
          final isLast = await raf.position() >= length;
          try {
            yield AesGcm.decrypt(
              key: key,
              nonce: _nonce(noncePrefix, index, last: isLast),
              ciphertext: ciphertext,
              aad: headerBytes,
            );
          } on AeadAuthenticationException {
            throw const BackupAuthenticationException();
          }
          sawLast = isLast;
          index++;
        }
        if (!sawLast) {
          throw const BackupAuthenticationException();
        }
      }

      final sink = output.openWrite();
      try {
        await sink.addStream(chunks().transform(gzip.decoder));
      } on BackupException {
        rethrow;
      } on FormatException {
        throw const BackupFormatException('Backup content is not readable');
      } finally {
        try {
          await sink.close();
        } catch (_) {
          // The error that stopped the stream is what matters.
        }
      }
    } finally {
      zeroBytes(key);
    }
    return BackupInfo(
      2,
      schemaVersion: header['schema_version'] as int?,
      createdAt: DateTime.tryParse(header['created_at'] as String? ?? ''),
    );
  }

  static Future<BackupInfo> _decryptV1(
    File input,
    File output,
    String password,
  ) async {
    final bytes = await input.readAsBytes();
    if (bytes.length < 44 + AesGcm.tagLength) {
      throw const BackupFormatException('Not a LedgerZero backup');
    }
    final salt = Uint8List.sublistView(bytes, 0, 32);
    final iv = Uint8List.sublistView(bytes, 32, 44);
    final ciphertext = Uint8List.sublistView(bytes, 44);
    final key = await deriveKey(
      password,
      KdfParams.pbkdf2(salt: Uint8List.fromList(salt), iterations: 100000),
    );
    try {
      final compressed = AesGcm.decrypt(
        key: key,
        nonce: Uint8List.fromList(iv),
        ciphertext: ciphertext,
      );
      final plain = const GZipDecoder().decodeBytes(compressed);
      await output.writeAsBytes(plain, flush: true);
    } on AeadAuthenticationException {
      throw const BackupAuthenticationException();
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException('Backup content is not readable');
    } finally {
      zeroBytes(key);
    }
    return const BackupInfo(1);
  }

  static bool _startsWithMagic(List<int> bytes) {
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) {
        return false;
      }
    }
    return true;
  }

  static Uint8List _nonce(Uint8List prefix, int index, {required bool last}) {
    final nonce = Uint8List(12);
    nonce.setRange(0, _noncePrefixLength, prefix);
    nonce[7] = (index >> 24) & 0xff;
    nonce[8] = (index >> 16) & 0xff;
    nonce[9] = (index >> 8) & 0xff;
    nonce[10] = index & 0xff;
    nonce[11] = last ? 1 : 0;
    return nonce;
  }

  static Uint8List _u32(int value) => Uint8List(4)
    ..[0] = (value >> 24) & 0xff
    ..[1] = (value >> 16) & 0xff
    ..[2] = (value >> 8) & 0xff
    ..[3] = value & 0xff;

  static int _readU32(List<int> b) {
    if (b.length != 4) {
      throw const BackupFormatException('Truncated backup');
    }
    return (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
  }
}
