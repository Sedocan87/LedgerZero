// Schema upgrade on a device: an encrypted (SQLCipher, raw key) database
// file at schema v14 — the last version before integer money — is opened by
// the current app database, migrated to the current schema and its data
// converted, with the SQLCipher build that ships in the app.
//
// The full matrix (v1, v14, v15, v16 -> current, structure and data) runs
// on the host in test/database/migration_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:path_provider/path_provider.dart';

import '../test/database/generated_migrations/schema_v14.dart' as v14;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an encrypted v14 database upgrades to the current schema', (
    tester,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final work = Directory(
      '${docs.path}/it_upgrade_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final file = File('${work.path}/ledger_zero.db');
    final key = secureRandomBytes(32);
    try {
      // The old app's database, created by the v14 schema.
      final old = v14.DatabaseAtV14(openEncryptedConnection(key, file: file));
      await old.customStatement(
        'INSERT INTO accounts (id, name, type, currency, starting_balance, '
        "current_balance, is_closed) VALUES ('a1', 'Checking', 'checking', "
        "'EUR', 12.345, 0, 0)",
      );
      await old.customStatement(
        'INSERT INTO transactions (id, account_id, date, amount, cleared, '
        "approved, is_deleted) VALUES ('t1', 'a1', "
        "'2024-05-03T00:00:00.000 +02:00', -2.675, 0, 1, 0)",
      );
      final before = await old.customSelect('PRAGMA user_version').getSingle();
      expect(before.data.values.first, 14);
      await old.close();
      expect(SqlCipher.canOpen(file, RawSqlCipherKey(key)), isTrue);

      // The current app opens and migrates it.
      final db = AppDatabase(openEncryptedConnection(key, file: file));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, AppDatabase.currentSchemaVersion);
      final account = await db.select(db.accounts).getSingle();
      expect(account.startingBalance, 1235); // 12.345 -> minor units
      final tx = await db.select(db.transactions).getSingle();
      expect(tx.amount, -268); // -2.675 -> minor units, half away from zero
      expect(tx.date, DateTime.utc(2024, 5, 3)); // calendar day kept
      expect(await db.accountsDao.getAccountBalance('a1'), 1235 - 268);
      await db.close();

      // Still encrypted with the same key after the upgrade.
      expect(SqlCipher.canOpen(file, RawSqlCipherKey(key)), isTrue);
    } finally {
      work.deleteSync(recursive: true);
    }
  });
}
