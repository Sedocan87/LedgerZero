import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/security/crypto/kdf.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:pointycastle/export.dart';

import '../../helpers/security_fakes.dart';

void main() {
  late Directory dir;
  late File plain;
  late File encrypted;
  late File output;
  late Uint8List content;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lz_backup_format_');
    plain = File('${dir.path}/plain.sqlite');
    encrypted = File('${dir.path}/backup.lzbk');
    output = File('${dir.path}/out.sqlite');
    // Partly random so gzip cannot shrink it to one chunk.
    content = Uint8List.fromList([
      ...utf8.encode('SQLite format 3\u0000 Rent 1250.00 Groceries '),
      ...secureRandomBytes(5000),
      ...List.filled(3000, 65),
    ]);
    plain.writeAsBytesSync(content);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> encrypt({
    int chunkSize = 1024,
    String password = 'backup pass',
  }) => BackupFormat.encryptFile(
    plaintext: plain,
    output: encrypted,
    password: password,
    schemaVersion: 16,
    kdf: fastKdf(),
    chunkSize: chunkSize,
  );

  test('v2 round trip over several chunks', () async {
    await encrypt();
    final bytes = encrypted.readAsBytesSync();
    expect(ascii.decode(bytes.sublist(0, 4)), 'LZBK');
    expect(bytes[4], 2);
    expect(latin1.decode(bytes).contains('Groceries'), isFalse);

    final info = await BackupFormat.decryptFile(
      input: encrypted,
      output: output,
      password: 'backup pass',
    );
    expect(info.formatVersion, 2);
    expect(info.schemaVersion, 16);
    expect(output.readAsBytesSync(), content);
  });

  test('header carries the KDF parameters and salt', () async {
    await encrypt();
    final bytes = encrypted.readAsBytesSync();
    final length = ByteData.sublistView(bytes, 5, 9).getUint32(0);
    final header = jsonDecode(utf8.decode(bytes.sublist(9, 9 + length)));
    expect(header['kdf']['alg'], 'argon2id');
    expect(header['kdf'], contains('salt'));
    expect(header['schema_version'], 16);
  });

  test('default backup KDF matches the password KDF', () {
    final params = KdfParams.recommended();
    expect(params.algorithm, KdfAlgorithm.argon2id);
    expect(params.memoryKiB, KdfParams.defaultArgon2MemoryKiB);
  });

  test('wrong password', () async {
    await encrypt();
    expect(
      () => BackupFormat.decryptFile(
        input: encrypted,
        output: output,
        password: 'wrong',
      ),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test('a modified header fails authentication', () async {
    await encrypt();
    final bytes = encrypted.readAsBytesSync();
    // Flip a byte inside the JSON header (the creation timestamp).
    final index = latin1.decode(bytes).indexOf('created_at') + 15;
    bytes[index] ^= 1;
    encrypted.writeAsBytesSync(bytes);
    await expectLater(
      BackupFormat.decryptFile(
        input: encrypted,
        output: output,
        password: 'backup pass',
      ),
      throwsA(isA<BackupException>()),
    );
  });

  test('truncation and appended data are detected', () async {
    await encrypt();
    final bytes = encrypted.readAsBytesSync();
    // Drop the final record: 4 + ciphertext of the last chunk.
    final truncated = File('${dir.path}/truncated.lzbk')
      ..writeAsBytesSync(bytes.sublist(0, bytes.length - 200));
    await expectLater(
      BackupFormat.decryptFile(
        input: truncated,
        output: output,
        password: 'backup pass',
      ),
      throwsA(isA<BackupAuthenticationException>()),
    );
    final appended = File('${dir.path}/appended.lzbk')
      ..writeAsBytesSync([...bytes, 0, 0, 0, 20, ...List.filled(20, 1)]);
    await expectLater(
      BackupFormat.decryptFile(
        input: appended,
        output: output,
        password: 'backup pass',
      ),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test('reads the old v1 format (PBKDF2 100k, no header)', () async {
    // Exactly what the previous BackupService wrote.
    final salt = secureRandomBytes(32);
    final iv = secureRandomBytes(12);
    final key =
        (PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
              ..init(Pbkdf2Parameters(salt, 100000, 32)))
            .process(Uint8List.fromList(utf8.encode('old password')));
    final compressed = const GZipEncoder().encode(content);
    final ct = AesGcm.encrypt(
      key: key,
      nonce: iv,
      plaintext: Uint8List.fromList(compressed),
    );
    final v1 = File('${dir.path}/old.lzbk')
      ..writeAsBytesSync([...salt, ...iv, ...ct]);

    final info = await BackupFormat.decryptFile(
      input: v1,
      output: output,
      password: 'old password',
    );
    expect(info.formatVersion, 1);
    expect(output.readAsBytesSync(), content);

    await expectLater(
      BackupFormat.decryptFile(input: v1, output: output, password: 'nope'),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test('unknown files and newer versions are rejected', () async {
    final junk = File('${dir.path}/junk.lzbk')..writeAsBytesSync([1, 2, 3]);
    await expectLater(
      BackupFormat.decryptFile(input: junk, output: output, password: 'x'),
      throwsA(isA<BackupFormatException>()),
    );
    final newer = File('${dir.path}/newer.lzbk')
      ..writeAsBytesSync([...ascii.encode('LZBK'), 3, 0, 0, 0, 2, 123, 125]);
    await expectLater(
      BackupFormat.decryptFile(input: newer, output: output, password: 'x'),
      throwsA(isA<BackupTooNewException>()),
    );
  });
}
