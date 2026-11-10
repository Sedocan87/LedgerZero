// A factory reset leaves no sync state behind: the sync controller (with
// the Wi-Fi sync service and the device id) is replaced, so Settings no
// longer shows the old connection.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/connectivity_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/security_fakes.dart' show InMemorySecureStore;

class _FakeConnectivity extends Fake implements ConnectivityService {
  @override
  Stream<ConnectionStatus> get connectionStatusStream => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_onboarded': true,
      'sync_provider': SyncProviderType.localWifi.name,
      'sync_frequency': SyncFrequency.manual.name,
    });
    prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityServiceProvider.overrideWithValue(_FakeConnectivity()),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      ],
    );
    addTearDown(c.dispose);
    // Kept alive as MyApp does (it listens to the sync state).
    c.listen(syncControllerProvider, (_, _) {});
  });

  test('after the reset the sync settings show no provider', () async {
    final before = c.read(syncControllerProvider.notifier);
    final lanBefore = c.read(lanSyncServiceProvider);
    final deviceIdBefore = c.read(syncDeviceIdProvider);
    expect(
      c.read(syncControllerProvider).selectedProvider,
      SyncProviderType.localWifi,
    );

    // What FactoryResetService does last.
    await prefs.clear();
    c.read(authProvider.notifier)
      ..setAuthenticated(false)
      ..setOnboarded(false);

    final state = c.read(syncControllerProvider);
    expect(c.read(syncControllerProvider.notifier), isNot(same(before)));
    expect(state.selectedProvider, SyncProviderType.none);
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
}
