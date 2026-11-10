import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/services/backup/auto_backup_service.dart';
import 'package:ledger_zero/services/backup/sync_rebootstrap.dart';
import 'package:ledger_zero/services/backup/transferred_install.dart';
import 'package:ledger_zero/services/sync/lan/lan_peers.dart';
import 'package:ledger_zero/services/sync/sync_device_id.dart';
import 'package:ledger_zero/services/sync/sync_local_state.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tmp;
  late Directory noBackup;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lz_transfer_');
    noBackup = Directory(p.join(tmp.path, 'no_backup'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  File marker() => File(p.join(noBackup.path, TransferredInstall.markerName));

  group('detect', () {
    test(
      'a new install is not moved; it writes both copies of its id',
      () async {
        final prefs0 = await prefs();
        expect(await TransferredInstall.detect(prefs0, noBackup), isFalse);
        final id = prefs0.getString(TransferredInstall.prefsKey);
        expect(id, isNotNull);
        expect(marker().readAsStringSync(), id);
        // The next start finds them matching.
        expect(await TransferredInstall.detect(prefs0, noBackup), isFalse);
        expect(prefs0.getString(TransferredInstall.prefsKey), id);
      },
    );

    test('preferences with an id but no marker came from another phone; '
        'the moved install gets an id of its own', () async {
      final prefs0 = await prefs({TransferredInstall.prefsKey: 'old-phone'});
      expect(await TransferredInstall.detect(prefs0, noBackup), isTrue);
      final id = prefs0.getString(TransferredInstall.prefsKey);
      expect(id, isNot('old-phone'));
      expect(marker().readAsStringSync(), id);
      // Only once.
      expect(await TransferredInstall.detect(prefs0, noBackup), isFalse);
    });

    test('a marker of a different install (the app was on the new phone '
        'before) also means moved', () async {
      noBackup.createSync(recursive: true);
      marker().writeAsStringSync('earlier-install');
      final prefs0 = await prefs({TransferredInstall.prefsKey: 'old-phone'});
      expect(await TransferredInstall.detect(prefs0, noBackup), isTrue);
      expect(
        prefs0.getString(TransferredInstall.prefsKey),
        allOf(isNot('old-phone'), isNot('earlier-install')),
      );
    });

    test('preferences without an id (data cleared by a factory reset) keep '
        'the marker id and are not moved', () async {
      noBackup.createSync(recursive: true);
      marker().writeAsStringSync('this-install');
      final prefs0 = await prefs({'user_onboarded': true});
      expect(await TransferredInstall.detect(prefs0, noBackup), isFalse);
      expect(prefs0.getString(TransferredInstall.prefsKey), 'this-install');
    });
  });

  group('becomeNewDevice', () {
    late File dbFile;

    setUp(() async {
      dbFile = File(p.join(tmp.path, 'db.sqlite'));
      final db = AppDatabase(NativeDatabase(dbFile));
      await db.syncDao.setValue(SyncLocalState.deviceIdKey, 'old-device-id');
      await db.syncDao.setValue(AppDatabase.memberIdKey, 'member-1');
      // A local change waiting for upload.
      await db.customStatement(
        "INSERT INTO payees (id, name) VALUES ('p1', 'Bakery')",
      );
      await db.close();
    });

    int count(sqlite.Database db, String sql) =>
        db.select(sql).first.values.first as int;

    test('drops the old device id, the change queue and the Wi-Fi peers, '
        'and asks for a sync re-bootstrap', () async {
      const oldId = '11111111-2222-4333-8444-555555555555';
      final prefs0 = await prefs({
        SyncDeviceId.prefsKey: oldId,
        LanPeers.prefsKey: '[]',
        'user_onboarded': true,
        AutoBackupService.enabledKey: true,
        AutoBackupService.lastSuccessKey: 1,
      });
      final before = sqlite.sqlite3.open(dbFile.path);
      expect(
        count(before, 'SELECT COUNT(*) FROM pending_sync_changes'),
        greaterThan(0),
      );
      before.close();

      await TransferredInstall.becomeNewDevice(prefs0, dbFile);

      expect(prefs0.getBool(SyncRebootstrap.prefsKey), isTrue);
      expect(prefs0.getString(LanPeers.prefsKey), isNull);
      expect(prefs0.getBool('user_onboarded'), isTrue);
      // Automatic backups stay on and run at the next start (the password
      // stayed on the old phone: that run asks for it).
      expect(prefs0.getBool(AutoBackupService.enabledKey), isTrue);
      expect(prefs0.getInt(AutoBackupService.lastSuccessKey), isNull);
      expect(SyncDeviceId.of(prefs0), isNot(oldId));
      final after = sqlite.sqlite3.open(dbFile.path);
      try {
        expect(count(after, 'SELECT COUNT(*) FROM pending_sync_changes'), 0);
        expect(
          after.select('SELECT value FROM sync_kv WHERE key = ?', [
            SyncLocalState.deviceIdKey,
          ]),
          isEmpty,
        );
        // The data and the household member stay.
        expect(count(after, 'SELECT COUNT(*) FROM payees'), 1);
        expect(
          after
              .select('SELECT value FROM sync_kv WHERE key = ?', [
                AppDatabase.memberIdKey,
              ])
              .single
              .values
              .single,
          'member-1',
        );
      } finally {
        after.close();
      }
    });

    test('start-up runs it only for a moved install', () async {
      final moved = await prefs({
        TransferredInstall.prefsKey: 'old-phone',
        SyncDeviceId.prefsKey: '11111111-2222-4333-8444-555555555555',
      });
      await TransferredInstall.checkAtStartup(
        moved,
        noBackupDirectory: () async => noBackup,
        databaseFile: () async => dbFile,
      );
      expect(moved.getBool(SyncRebootstrap.prefsKey), isTrue);
      expect(moved.getString(SyncDeviceId.prefsKey), isNull);

      // The same install starting again: nothing more happens.
      await moved.remove(SyncRebootstrap.prefsKey);
      await TransferredInstall.checkAtStartup(
        moved,
        noBackupDirectory: () async => noBackup,
        databaseFile: () async => dbFile,
      );
      expect(moved.getBool(SyncRebootstrap.prefsKey), isNull);
    });

    test('a restore from Android\'s cloud backup (reinstall, or a new phone '
        'set up from the backup) is handled like a transfer', () async {
      // What the backup holds: the preferences with the old install id
      // and db.sqlite with its -wal, including changes that were never
      // checkpointed. The no-backup directory starts empty after a
      // reinstall or on a new phone.
      final source = AppDatabase(NativeDatabase(dbFile));
      await source.customStatement(
        "INSERT INTO payees (id, name) VALUES ('p2', 'Kiosk')",
      );
      final restoredDir = Directory(p.join(tmp.path, 'restored'))
        ..createSync();
      final restored = File(p.join(restoredDir.path, 'db.sqlite'));
      dbFile.copySync(restored.path);
      final wal = File('${dbFile.path}-wal');
      expect(wal.lengthSync(), greaterThan(0));
      wal.copySync('${restored.path}-wal');
      await source.close();

      const oldId = '11111111-2222-4333-8444-555555555555';
      final prefs0 = await prefs({
        TransferredInstall.prefsKey: 'backed-up-install',
        SyncDeviceId.prefsKey: oldId,
        LanPeers.prefsKey: '[]',
        'user_onboarded': true,
      });
      expect(noBackup.existsSync(), isFalse);

      await TransferredInstall.checkAtStartup(
        prefs0,
        noBackupDirectory: () async => noBackup,
        databaseFile: () async => restored,
      );

      expect(prefs0.getBool(SyncRebootstrap.prefsKey), isTrue);
      expect(prefs0.getString(SyncDeviceId.prefsKey), isNull);
      expect(prefs0.getString(LanPeers.prefsKey), isNull);
      expect(
        prefs0.getString(TransferredInstall.prefsKey),
        allOf(isNotNull, isNot('backed-up-install')),
      );
      expect(
        marker().readAsStringSync(),
        prefs0.getString(TransferredInstall.prefsKey),
      );
      final after = sqlite.sqlite3.open(restored.path);
      try {
        // Every row, also the one that was only in the WAL.
        expect(count(after, 'SELECT COUNT(*) FROM payees'), 2);
        expect(count(after, 'SELECT COUNT(*) FROM pending_sync_changes'), 0);
        expect(
          after.select('SELECT value FROM sync_kv WHERE key = ?', [
            SyncLocalState.deviceIdKey,
          ]),
          isEmpty,
        );
      } finally {
        after.close();
      }
    });

    test(
      'without a no-backup directory (not Android) nothing happens',
      () async {
        final prefs0 = await prefs({TransferredInstall.prefsKey: 'old-phone'});
        await TransferredInstall.checkAtStartup(
          prefs0,
          noBackupDirectory: () async => null,
          databaseFile: () async => dbFile,
        );
        expect(prefs0.getString(TransferredInstall.prefsKey), 'old-phone');
        expect(prefs0.getBool(SyncRebootstrap.prefsKey), isNull);
      },
    );
  });
}
