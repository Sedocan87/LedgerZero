import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/services/backup/auto_backup_service.dart';
import 'package:ledger_zero/services/backup/backup_format.dart';
import 'package:ledger_zero/services/backup/backup_scheduler.dart';
import 'package:ledger_zero/services/backup/backup_service.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/security_fakes.dart';
import '../../helpers/test_database.dart';

class _SilentNotifications extends Fake implements NotificationService {
  @override
  Future<void> showBackupReminderNotification() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestDatabase t;
  late Directory dir;
  late SharedPreferences prefs;
  late InMemorySecureStore store;
  late DateTime now;
  var backupServiceCalls = 0;
  var failBackups = false;

  setUp(() async {
    t = TestDatabase();
    dir = Directory.systemTemp.createTempSync('lz_auto_backup_');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = InMemorySecureStore();
    now = DateTime(2026, 10, 19, 9, 0);
    backupServiceCalls = 0;
    failBackups = false;
  });

  tearDown(() async {
    await t.close();
    dir.deleteSync(recursive: true);
  });

  BackupService backupService() {
    backupServiceCalls++;
    if (failBackups) {
      throw StateError('database closed');
    }
    return BackupService(
      t.db,
      files: ExportFileService(
        baseDirectory: () async => Directory(p.join(dir.path, 'tmp')),
        deferDeletion: false,
      ),
      backupScheduler: BackupScheduler(prefs, _SilentNotifications()),
      kdf: fastKdf,
    );
  }

  AutoBackupService service({int keep = 7}) => AutoBackupService(
    prefs,
    store,
    backupService: backupService,
    baseDirectory: () async => dir,
    now: () => now,
    keep: keep,
  );

  List<String> backupNames() => Directory(
    p.join(dir.path, 'backups'),
  ).listSync().map((e) => p.basename(e.path)).toList()..sort();

  test('off by default: nothing is due and nothing is written', () async {
    final auto = service();
    expect(auto.isEnabled, isFalse);
    expect(auto.isDue, isFalse);
    expect(await auto.runIfDue(), isNull);
    expect(backupServiceCalls, 0);
    expect(await auto.listBackups(), isEmpty);
  });

  test('enable stores the password, writes a backup that opens with it and '
      'records the backup for the reminder', () async {
    await t.addAccount(id: 'a1', name: 'Household Checking');
    final auto = service();

    final file = await auto.enable('correct horse battery');

    expect(auto.isEnabled, isTrue);
    expect(
      await store.read(AutoBackupService.passwordKey),
      'correct horse battery',
    );
    expect(p.basename(file.path), 'ledgerzero_auto_20261019_090000.lzbk');
    expect(p.dirname(file.path), p.join(dir.path, 'backups'));
    expect(auto.lastSuccess, now);
    expect(auto.lastError, isNull);
    expect(prefs.getInt('last_backup_timestamp'), isNotNull);
    // No plaintext snapshot is left behind.
    expect(
      Directory(
        p.join(dir.path, 'tmp'),
      ).listSync(recursive: true).whereType<File>(),
      isEmpty,
    );

    final out = File(p.join(dir.path, 'check.sqlite'));
    await BackupFormat.decryptFile(
      input: file,
      output: out,
      password: 'correct horse battery',
    );
    expect(
      ascii.decode(out.readAsBytesSync().sublist(0, 15)),
      'SQLite format 3',
    );
  });

  test('a run is due a day after the last success, not before', () async {
    final auto = service();
    await auto.enable('correct horse battery');
    expect(auto.isDue, isFalse);

    now = now.add(const Duration(hours: 23));
    expect(auto.isDue, isFalse);
    expect(await auto.runIfDue(), isNull);

    now = now.add(const Duration(hours: 1));
    expect(auto.isDue, isTrue);
    expect(await auto.runIfDue(), isNotNull);
    expect(auto.lastSuccess, now);
    expect(backupNames(), [
      'ledgerzero_auto_20261019_090000.lzbk',
      'ledgerzero_auto_20261020_090000.lzbk',
    ]);
  });

  test(
    'a failure is recorded, logged away and retried after an hour',
    () async {
      final auto = service();
      await auto.enable('correct horse battery');
      now = now.add(const Duration(days: 1));
      failBackups = true;

      expect(await auto.runIfDue(), isNull);
      expect(auto.lastError, contains('database closed'));
      expect(auto.lastAttempt, now);
      expect(auto.lastSuccess, now.subtract(const Duration(days: 1)));
      // Not retried right away.
      final calls = backupServiceCalls;
      expect(auto.isDue, isFalse);
      expect(await auto.runIfDue(), isNull);
      expect(backupServiceCalls, calls);

      now = now.add(const Duration(hours: 1));
      failBackups = false;
      expect(await auto.runIfDue(), isNotNull);
      expect(auto.lastError, isNull);
      expect(auto.lastSuccess, now);
    },
  );

  test('runNow throws when the stored password is gone', () async {
    final auto = service();
    await auto.enable('correct horse battery');
    await store.delete(AutoBackupService.passwordKey);
    now = now.add(const Duration(days: 1));

    await expectLater(
      auto.runNow(),
      throwsA(isA<AutoBackupNotConfiguredException>()),
    );
    expect(auto.lastError, isNotNull);
    expect(auto.isEnabled, isTrue);
  });

  test('only the newest backups are kept', () async {
    final auto = service(keep: 2);
    await auto.enable('correct horse battery');
    for (var i = 0; i < 3; i++) {
      now = now.add(const Duration(days: 1));
      await auto.runNow();
    }
    expect(backupNames(), [
      'ledgerzero_auto_20261021_090000.lzbk',
      'ledgerzero_auto_20261022_090000.lzbk',
    ]);
    final listed = await auto.listBackups();
    expect(listed.map((b) => b.createdAt), [
      DateTime(2026, 10, 22, 9),
      DateTime(2026, 10, 21, 9),
    ]);
    expect(listed.every((b) => b.sizeBytes > 0), isTrue);
  });

  test('other files in the folder are ignored', () async {
    final auto = service();
    await auto.enable('correct horse battery');
    File(p.join(dir.path, 'backups', 'notes.txt')).writeAsStringSync('x');
    File(
      p.join(dir.path, 'backups', 'ledgerzero_backup_manual.lzbk'),
    ).writeAsStringSync('x');
    expect((await auto.listBackups()).length, 1);
  });

  test('disable forgets the password and keeps the files; deleteAll '
      'removes them', () async {
    final auto = service();
    await auto.enable('correct horse battery');

    await auto.disable();
    expect(auto.isEnabled, isFalse);
    expect(auto.isDue, isFalse);
    expect(await store.read(AutoBackupService.passwordKey), isNull);
    expect(backupNames(), hasLength(1));

    await auto.deleteAll();
    expect(backupNames(), isEmpty);
  });

  test('changePassword applies to the next backup', () async {
    final auto = service();
    await auto.enable('correct horse battery');
    await auto.changePassword('staple battery horse');
    now = now.add(const Duration(days: 1));
    final file = await auto.runNow();
    final out = File(p.join(dir.path, 'check.sqlite'));
    await expectLater(
      BackupFormat.decryptFile(
        input: file,
        output: out,
        password: 'correct horse battery',
      ),
      throwsA(isA<BackupAuthenticationException>()),
    );
    await BackupFormat.decryptFile(
      input: file,
      output: out,
      password: 'staple battery horse',
    );
  });
}
