import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lz_conn_');
    file = File('${dir.path}/ledger_zero.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> writeAccount(Uint8List key) async {
    final db = AppDatabase(openEncryptedConnection(key, file: file));
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'acc-1',
            name: 'Secret Savings Account',
            type: 'savings',
          ),
        );
    await db.close();
  }

  test(
    'creates an encrypted file that reopens with the same raw key',
    () async {
      final key = secureRandomBytes(32);
      await writeAccount(key);

      final bytes = file.readAsBytesSync();
      expect(
        ascii.decode(bytes.sublist(0, 15), allowInvalid: true),
        isNot('SQLite format 3'),
      );
      expect(latin1.decode(bytes).contains('Secret Savings Account'), isFalse);

      final db = AppDatabase(openEncryptedConnection(key, file: file));
      final accounts = await db.select(db.accounts).get();
      expect(accounts.single.name, 'Secret Savings Account');
      await db.close();
    },
  );

  test('the caller may zero its copy of the key after opening', () async {
    final key = secureRandomBytes(32);
    final copy = Uint8List.fromList(key);
    final db = AppDatabase(openEncryptedConnection(key, file: file));
    zeroBytes(key);
    await db.select(db.accounts).get();
    await db.close();
    expect(SqlCipher.canOpen(file, RawSqlCipherKey(copy)), isTrue);
  });

  test('a wrong key fails closed', () async {
    await writeAccount(secureRandomBytes(32));
    final db = AppDatabase(
      openEncryptedConnection(secureRandomBytes(32), file: file),
    );
    await expectLater(
      db.select(db.accounts).get(),
      throwsA(isA<DatabaseKeyException>()),
    );
    await db.close();
  });

  test('an unencrypted database is not opened with a key either', () async {
    final plain = AppDatabase(NativeDatabase(file));
    await plain.select(plain.accounts).get();
    await plain.close();

    final db = AppDatabase(
      openEncryptedConnection(secureRandomBytes(32), file: file),
    );
    await expectLater(
      db.select(db.accounts).get(),
      throwsA(isA<DatabaseKeyException>()),
    );
    await db.close();
  });

  test('keys are validated before they reach SQL', () {
    expect(
      () => RawSqlCipherKey(Uint8List(16)),
      throwsA(isA<DatabaseKeyException>()),
    );
    expect(
      () => LegacyPassphraseKey("abc'; DROP TABLE x; --"),
      throwsA(isA<DatabaseKeyException>()),
    );
    expect(RawSqlCipherKey(Uint8List(32)).sqlLiteral, '"x\'${'0' * 64}\'"');
  });
}
