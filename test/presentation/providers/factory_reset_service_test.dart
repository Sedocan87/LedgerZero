import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/factory_reset_provider.dart';
import 'package:ledger_zero/presentation/providers/pro_provider.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory docs;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('lz_reset_');
  });

  tearDown(() => docs.delete(recursive: true));

  FactoryResetService service({
    required List<String> log,
    Object? failing,
    Future<void> Function()? deleteSyncFiles,
  }) {
    Future<void> Function() step(String name) => () async {
      log.add(name);
      if (name == failing) {
        throw StateError('$name failed');
      }
    };
    return FactoryResetService(
      closeSession: step('session'),
      deleteDatabase: step('database'),
      forgetAutoBackupPassword: step('auto backup password'),
      deleteExports: step('exports'),
      clearCapturedNotifications: step('capture'),
      deleteErrorReports: step('reports'),
      unpairWifiSync: step('unpair'),
      deleteSyncFiles: deleteSyncFiles ?? step('sync files'),
      clearPreferences: step('prefs'),
      markNotOnboarded: () => log.add('onboarding'),
    );
  }

  test('unpairs Wi-Fi sync and deletes the local sync files', () async {
    final outbox = Directory('${docs.path}/sync/outbox')
      ..createSync(recursive: true);
    File('${outbox.path}/x.lzsync').writeAsStringSync('x');
    Directory('${docs.path}/sync/lan').createSync(recursive: true);
    final log = <String>[];
    await service(
      log: log,
      deleteSyncFiles: () => SyncOutbox.deleteAllSyncFiles(docs),
    ).reset();
    expect(Directory('${docs.path}/sync').existsSync(), isFalse);
    expect(log, containsAllInOrder(['session', 'database', 'unpair']));
    expect(log.last, 'onboarding');
  });

  test(
    'a failing step does not stop the others; the error propagates',
    () async {
      final log = <String>[];
      await expectLater(
        service(log: log, failing: 'database').reset(),
        throwsA(isA<StateError>()),
      );
      expect(log, contains('prefs'));
      expect(log.last, 'onboarding');
    },
  );

  test('a factory reset clears the preferences but keeps the Pro '
      'purchase', () async {
    SharedPreferences.setMockInitialValues({
      ProController.unlockedKey: true,
      'settings_language': 'de',
    });
    final prefs = await SharedPreferences.getInstance();
    await clearPreferencesKeepingPro(prefs);
    expect(prefs.getKeys(), {ProController.unlockedKey});
    expect(prefs.getBool(ProController.unlockedKey), isTrue);

    SharedPreferences.setMockInitialValues({'settings_language': 'de'});
    final free = await SharedPreferences.getInstance();
    await clearPreferencesKeepingPro(free);
    expect(free.getKeys(), isEmpty);
  });
}
