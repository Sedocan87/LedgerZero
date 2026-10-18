import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/factory_reset_provider.dart';
import 'package:ledger_zero/services/sync/sync_outbox.dart';

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
      deleteDeviceKey: step('key'),
      deleteLegacyKeys: step('legacy'),
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
        service(log: log, failing: 'key').reset(),
        throwsA(isA<StateError>()),
      );
      expect(log, contains('prefs'));
      expect(log.last, 'onboarding');
    },
  );
}
