// A factory reset leaves no sync state behind: the Google account is
// forgotten and the sync controller (with the Wi-Fi sync service and the
// device id) is replaced, so Settings no longer shows the old connection.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/providers/factory_reset_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/security_fakes.dart' show InMemorySecureStore;

class _Account extends Fake implements GoogleSignInAccount {
  @override
  String get email => 'old@example.com';
}

class _FakeAuth extends Fake implements GoogleAuthService {
  final users = StreamController<GoogleSignInAccount?>.broadcast();
  int forgets = 0;

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => users.stream;

  @override
  Future<void> forgetAccount({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    forgets++;
  }
}

class _FakeConnectivity extends Fake implements ConnectivityService {
  @override
  Stream<ConnectionStatus> get connectionStatusStream => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  late SharedPreferences prefs;
  late _FakeAuth auth;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_onboarded': true,
      'sync_provider': SyncProviderType.googleDrive.name,
      'sync_frequency': SyncFrequency.manual.name,
    });
    prefs = await SharedPreferences.getInstance();
    auth = _FakeAuth();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        googleAuthServiceProvider.overrideWithValue(auth),
        connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      ],
    );
    addTearDown(c.dispose);
    // Kept alive as MyApp does (it listens to the sync state).
    c.listen(syncControllerProvider, (_, _) {});
  });

  test('the reset forgets the Google account', () async {
    await c.read(factoryResetServiceProvider).signOutGoogle();
    expect(auth.forgets, 1);
  });

  test('after the reset the sync settings show no provider and no '
      'account', () async {
    final before = c.read(syncControllerProvider.notifier);
    final lanBefore = c.read(lanSyncServiceProvider);
    final deviceIdBefore = c.read(syncDeviceIdProvider);
    auth.users.add(_Account());
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(syncControllerProvider).selectedProvider,
      SyncProviderType.googleDrive,
    );
    expect(c.read(syncControllerProvider).accountEmail, 'old@example.com');

    // What FactoryResetService does last.
    await prefs.clear();
    c.read(authProvider.notifier)
      ..setAuthenticated(false)
      ..setOnboarded(false);

    final state = c.read(syncControllerProvider);
    expect(c.read(syncControllerProvider.notifier), isNot(same(before)));
    expect(state.selectedProvider, SyncProviderType.none);
    expect(state.accountEmail, isNull);
    expect(state.status, isNot(SyncStatus.connected));
    expect(state.lastSyncTime, isNull);
    // A fresh Wi-Fi sync service (no pairing) under the new device id.
    final lan = c.read(lanSyncServiceProvider);
    expect(lan, isNot(same(lanBefore)));
    expect(lan.isPaired, isFalse);
    expect(lan.isRunning, isFalse);
    expect(c.read(syncDeviceIdProvider), isNot(deviceIdBefore));
    expect(lan.deviceId, c.read(syncDeviceIdProvider));
  });

  test('Google sign-out failing (offline) does not fail the reset', () async {
    final log = <String>[];
    Future<void> Function() step(String name) =>
        () async => log.add(name);
    final service = FactoryResetService(
      closeSession: step('session'),
      deleteDatabase: step('database'),
      deleteDeviceKey: step('key'),
      deleteLegacyKeys: step('legacy'),
      forgetAutoBackupPassword: step('auto backup password'),
      deleteExports: step('exports'),
      clearCapturedNotifications: step('capture'),
      deleteErrorReports: step('reports'),
      unpairWifiSync: step('unpair'),
      signOutGoogle: () async => throw StateError('offline'),
      deleteSyncFiles: step('sync files'),
      clearPreferences: step('prefs'),
      markNotOnboarded: () => log.add('onboarding'),
    );
    await service.reset();
    expect(log, containsAllInOrder(['unpair', 'prefs', 'onboarding']));
  });
}
