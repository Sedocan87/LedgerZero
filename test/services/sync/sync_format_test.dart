import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/security/crypto/aead.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/sync/format/sync_change.dart';
import 'package:ledger_zero/services/sync/format/sync_file_codec.dart';
import 'package:ledger_zero/services/sync/format/sync_file_name.dart';
import 'package:ledger_zero/services/sync/format/sync_manifest.dart';
import 'package:ledger_zero/services/sync/sync_schema.dart';

import '../../helpers/sync_simulation.dart';

const device = '0f8fad5b-d9cb-469f-a165-70867728950e';

SyncFileHeader header({int sequence = 1, int schema = 17}) => SyncFileHeader(
  kind: SyncFileKind.changes,
  deviceId: device,
  sequence: sequence,
  schemaVersion: schema,
  changeCount: 2,
  maxVersion: 20,
  vector: const {'9b2c6f3e-1d4a-4c8b-9e7f-2a1b3c4d5e6f': 4},
  createdAt: DateTime.utc(2030),
);

const changes = [
  SyncChange(
    table: 'payees',
    id: 'p1',
    deleted: false,
    version: 10,
    deviceId: device,
    row: {'id': 'p1', 'name': 'Shop', 'color': 3, 'notes': null},
  ),
  SyncChange(
    table: 'accounts',
    id: 'a1',
    deleted: true,
    version: 20,
    deviceId: device,
  ),
];

void main() {
  group('file names', () {
    test('round trip and strict parsing', () {
      final name = SyncFileName.changes(device, 42);
      expect(name, '${device}_000000000042.lzsync');
      final parsed = SyncFileName.tryParse(name)!;
      expect(parsed.deviceId, device);
      expect(parsed.sequence, 42);
      expect(parsed.kind, SyncFileKind.changes);
      expect(
        SyncFileName.tryParse(SyncFileName.snapshot(device, 7))!.kind,
        SyncFileKind.snapshot,
      );
      for (final bad in [
        '',
        '../$name',
        './$name',
        '$name/..',
        '${device}_000000000000.lzsync',
        '${device}_00000000042.lzsync',
        '${device}_000000000042.lzsync.tmp',
        '${device}_000000000042.json.gz',
        '${device.toUpperCase()}_000000000042.lzsync',
        'C:\\$name',
        '$name\u0000',
      ]) {
        expect(SyncFileName.tryParse(bad), isNull, reason: bad);
      }
    });

    test('sequences sort numerically through zero padding', () {
      final names = [10, 9, 100, 1].map((s) => SyncFileName.changes(device, s))
        ..toList();
      final sorted = names.toList()..sort();
      expect(sorted.map((n) => SyncFileName.tryParse(n)!.sequence), [
        1,
        9,
        10,
        100,
      ]);
    });
  });

  group('codec', () {
    final key = secureRandomBytes(32);

    test('encrypts and decodes', () {
      final bytes = SyncFileCodec.encode(
        header: header(),
        changes: changes,
        key: key,
      );
      expect(latin1.decode(bytes), isNot(contains('Shop')));
      final file = SyncFileCodec.decode(bytes, key);
      expect(file.header.sequence, 1);
      expect(file.header.vector.values.single, 4);
      expect(file.changes.first.row!['name'], 'Shop');
      expect(file.changes.last.deleted, isTrue);
    });

    test('a wrong key or any modified byte fails authentication', () {
      final bytes = SyncFileCodec.encode(
        header: header(),
        changes: changes,
        key: key,
      );
      expect(
        () => SyncFileCodec.decode(bytes, secureRandomBytes(32)),
        throwsA(isA<AeadAuthenticationException>()),
      );
      // Flip one byte of the ciphertext.
      final tampered = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 1;
      expect(
        () => SyncFileCodec.decode(tampered, key),
        throwsA(isA<AeadAuthenticationException>()),
      );
      // Re-label the header (e.g. another sequence): the AAD differs.
      final headerText = latin1.decode(bytes);
      final relabeled = Uint8List.fromList(
        latin1.encode(headerText.replaceFirst('"seq":1', '"seq":2')),
      );
      expect(relabeled, isNot(bytes));
      expect(
        () => SyncFileCodec.decode(relabeled, key),
        throwsA(
          anyOf(
            isA<AeadAuthenticationException>(),
            isA<SyncFileFormatException>(),
          ),
        ),
      );
    });

    test('truncated files are rejected', () {
      final bytes = SyncFileCodec.encode(
        header: header(),
        changes: changes,
        key: key,
      );
      for (final length in [0, 3, 8, 40, bytes.length - 1]) {
        expect(
          () => SyncFileCodec.decode(
            Uint8List.sublistView(bytes, 0, length),
            key,
          ),
          throwsA(
            anyOf(
              isA<SyncFileFormatException>(),
              isA<AeadAuthenticationException>(),
            ),
          ),
          reason: 'length $length',
        );
      }
    });

    test('a newer schema is reported after authentication', () {
      final bytes = SyncFileCodec.encode(
        header: header(schema: 99),
        changes: changes,
        key: key,
      );
      expect(
        () => SyncFileCodec.decode(bytes, key, maxSchemaVersion: 17),
        throwsA(isA<SyncFileNewerSchemaException>()),
      );
      expect(
        () => SyncFileCodec.decode(
          bytes,
          secureRandomBytes(32),
          maxSchemaVersion: 17,
        ),
        throwsA(isA<AeadAuthenticationException>()),
      );
    });
  });

  group('manifest', () {
    test('derives the key; a wrong passphrase fails the key check', () async {
      final (manifest, key) = await SyncManifest.create(
        'my sync passphrase',
        kdf: fastKdf(),
      );
      final copy = SyncManifest.fromBytes(manifest.toBytes());
      final again = await copy.unlock('my sync passphrase');
      expect(again, key);
      expect(copy.verifyKey(key), isTrue);
      await expectLater(
        copy.unlock('wrong'),
        throwsA(isA<WrongSyncPassphraseException>()),
      );
    });

    test('tampered parameters fail the key check', () async {
      final (manifest, key) = await SyncManifest.create(
        'my sync passphrase',
        kdf: fastKdf(),
      );
      final json =
          jsonDecode(utf8.decode(manifest.toBytes())) as Map<String, dynamic>;
      (json['kdf'] as Map<String, dynamic>)['t'] = 2;
      final tampered = SyncManifest.fromBytes(utf8.encode(jsonEncode(json)));
      expect(tampered.verifyKey(key), isFalse);
      expect(
        () => SyncManifest.fromBytes(utf8.encode('{"format":"x"}')),
        throwsA(isA<InvalidSyncManifestException>()),
      );
    });
  });

  group('schema', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('dependency order lists parents before children', () async {
      final schema = SyncSchema.of(db);
      expect(schema.tables.keys.toSet(), AppDatabase.syncedTables.toSet());
      for (final table in AppDatabase.syncedTables) {
        final fks = await db
            .customSelect('PRAGMA foreign_key_list("$table")')
            .get();
        for (final fk in fks) {
          final parent = fk.data['table'] as String;
          if (parent == table) {
            continue;
          }
          expect(
            schema[parent]!.rank,
            lessThan(schema[table]!.rank),
            reason: '$table -> $parent',
          );
        }
      }
    });

    test('natural keys come from the table definitions', () {
      final schema = SyncSchema.of(db);
      expect(schema['budgets']!.naturalKeys, [
        ['category_id', 'month'],
      ]);
      expect(schema['report_notes']!.naturalKeys, [
        ['date'],
      ]);
      expect(schema['scheduled_transactions']!.columns, contains('anchor_day'));
      expect(schema['scheduled_transactions']!.columns, contains('memo'));
    });

    test('updated_at values become microsecond versions', () {
      expect(SyncSchema.versionOf(null), 0);
      expect(
        SyncSchema.versionOf('2024-01-01T00:00:00.000Z'),
        DateTime.utc(2024).microsecondsSinceEpoch,
      );
      expect(
        SyncSchema.versionOf('2024-01-01T00:00:00.000001Z'),
        DateTime.utc(2024).microsecondsSinceEpoch + 1,
      );
    });

    test('triggers fill in updated_at and record change times', () async {
      await db.customStatement(
        "INSERT INTO payees (id, name, is_favorite) VALUES ('p', 'P', 0)",
      );
      final row = await db
          .customSelect("SELECT updated_at FROM payees WHERE id = 'p'")
          .getSingle();
      expect(row.data['updated_at'], isNotNull);
      await db.customStatement(
        "UPDATE payees SET updated_at = '2020-01-01T00:00:00.000Z' "
        "WHERE id = 'p'",
      );
      await db.customStatement("UPDATE payees SET name = 'Q' WHERE id = 'p'");
      final touched = await db
          .customSelect("SELECT updated_at FROM payees WHERE id = 'p'")
          .getSingle();
      expect(
        SyncSchema.versionOf(touched.data['updated_at']),
        greaterThan(DateTime.utc(2020).microsecondsSinceEpoch),
      );
      await db.customStatement("DELETE FROM payees WHERE id = 'p'");
      final pending = await db
          .customSelect(
            'SELECT action, old_updated_at FROM pending_sync_changes '
            'ORDER BY id',
          )
          .get();
      // (Filling in updated_at on insert also records an UPDATE.)
      final actions = pending.map((r) => r.data['action']).toList();
      expect(actions, containsAll(['INSERT', 'UPDATE']));
      expect(actions.last, 'DELETE');
      expect(pending.last.data['old_updated_at'], isNotNull);

      // No capture while a change file is applied.
      await db.customStatement('DELETE FROM pending_sync_changes');
      await db.customStatement('INSERT INTO sync_applying (id) VALUES (1)');
      await db.customStatement(
        "INSERT INTO payees (id, name, is_favorite) VALUES ('r', 'R', 0)",
      );
      final none = await db
          .customSelect('SELECT COUNT(*) AS c FROM pending_sync_changes')
          .getSingle();
      expect(none.data['c'], 0);
      final untouched = await db
          .customSelect("SELECT updated_at FROM payees WHERE id = 'r'")
          .getSingle();
      expect(untouched.data['updated_at'], isNull);
    });
  });
}
