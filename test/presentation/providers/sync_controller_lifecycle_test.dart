import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:ledger_zero/data/database/database.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/services/sync/connectivity_service.dart';
import 'package:ledger_zero/services/sync/google_auth_service.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';
import 'package:ledger_zero/services/sync/transport/sync_transport.dart';

import '../../helpers/sync_simulation.dart';
import '../../helpers/test_database.dart';

class FakeEngine implements SyncEngine {
  int runs = 0;
  Object? error;
  Completer<void>? gate;
  final cancellations = <SyncCancellation>[];

  @override
  Future<SyncRunReport> sync({SyncCancellation? cancellation}) async {
    runs++;
    cancellations.add(cancellation!);
    final g = gate;
    if (g != null) {
      await g.future;
    }
    cancellation.check();
    final e = error;
    if (e != null) {
      throw e;
    }
    return const SyncRunReport(setup: SyncSetupStatus.ready);
  }

  @override
  Future<SyncSetupStatus> setupStatus() async => SyncSetupStatus.ready;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeConnectivity implements ConnectivityService {
  final controller = StreamController<ConnectionStatus>.broadcast();
  bool connected = true;
  bool wifi = true;

  @override
  Stream<ConnectionStatus> get connectionStatusStream => controller.stream;
  @override
  Future<bool> get isConnected async => connected;
  @override
  Future<bool> get isWifi async => wifi;
  @override
  Future<void> dispose() => controller.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements GoogleAuthService {
  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => const Stream.empty();
  @override
  Future<bool> isSignedIn() async => false;
  @override
  Future<void> signInSilently() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyTransport implements SyncTransport {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TestDatabase t;
  late FakeEngine engine;
  late FakeConnectivity connectivity;
  late InMemoryPrefs prefs;
  final transport = DummyTransport();

  SyncController controller({
    SyncFrequency frequency = SyncFrequency.realtime,
    Duration? interval,
    bool wifiOnly = false,
    String provider = 'googleDrive',
  }) {
    prefs.values['sync_provider'] = provider;
    prefs.values['sync_frequency'] = frequency.name;
    prefs.values['sync_on_wifi_only'] = wifiOnly;
    final c = SyncController(
      authService: FakeAuth(),
      prefs: prefs,
      connectivity: connectivity,
      dependencies: () => SyncDependencies(
        engineFor: (_) => engine,
        dao: t.db.syncDao,
        resolver: SyncConflictResolver(t.db),
      ),
      transportFor: (p) => p == SyncProviderType.none ? null : transport,
      debounce: const Duration(milliseconds: 60),
      resumeThreshold: const Duration(milliseconds: 100),
      intervalFor: (f) => f == SyncFrequency.realtime && interval != null
          ? interval
          : const Duration(hours: 1),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle([int ms = 30]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> localChange(String id) => t.db.customInsert(
    "INSERT INTO payees (id, name, is_favorite) VALUES ('$id', 'P', 0)",
    updates: {t.db.payees},
  );

  setUp(() {
    t = TestDatabase();
    engine = FakeEngine();
    connectivity = FakeConnectivity();
    prefs = InMemoryPrefs();
  });

  tearDown(() async {
    await t.close();
  });

  test('paused while locked; syncs on unlock; lock cancels the run', () async {
    final c = controller();
    expect(c.state.paused, isTrue);
    await settle();
    expect(engine.runs, 0);

    engine.gate = Completer<void>();
    await c.onLockStateChanged(AppLockState.unlocked);
    await settle();
    expect(c.state.paused, isFalse);
    expect(engine.runs, 1);

    await c.onLockStateChanged(AppLockState.locked);
    expect(c.state.paused, isTrue);
    expect(engine.cancellations.single.isCancelled, isTrue);
    engine.gate!.complete();
    await settle();
    // No error state from the cancelled run, no further runs while locked.
    expect(c.state.status, isNot(SyncStatus.error));
    await localChange('p1');
    await settle(150);
    expect(engine.runs, 1);

    engine.gate = null;
    await c.onLockStateChanged(AppLockState.unlocked);
    await settle();
    expect(engine.runs, 2);
  });

  test('local changes trigger one debounced sync', () async {
    final c = controller();
    await c.onLockStateChanged(AppLockState.unlocked);
    await settle();
    final afterUnlock = engine.runs;
    await localChange('p1');
    await settle(20);
    await localChange('p2');
    await settle(20);
    await localChange('p3');
    expect(engine.runs, afterUnlock);
    await settle(200);
    expect(engine.runs, afterUnlock + 1);
  });

  test('no automatic sync when the frequency is manual', () async {
    final c = controller(
      frequency: SyncFrequency.manual,
      interval: const Duration(milliseconds: 20),
    );
    await c.onLockStateChanged(AppLockState.unlocked);
    await localChange('p1');
    connectivity.controller.add(ConnectionStatus.offline);
    connectivity.controller.add(ConnectionStatus.online);
    c.onAppResumed();
    await settle(200);
    expect(engine.runs, 0);

    await c.syncNow();
    expect(engine.runs, 1);
  });

  test('periodic timer, reconnect and resume trigger syncs', () async {
    final c = controller(interval: const Duration(milliseconds: 50));
    await c.onLockStateChanged(AppLockState.unlocked);
    await settle(180);
    expect(engine.runs, greaterThanOrEqualTo(3));

    await c.setSyncFrequency(SyncFrequency.manual);
    await settle();
    final before = engine.runs;
    await settle(150);
    expect(engine.runs, before);

    await c.setSyncFrequency(SyncFrequency.everyHour);
    connectivity.controller.add(ConnectionStatus.offline);
    connectivity.controller.add(ConnectionStatus.online);
    await settle();
    expect(engine.runs, before + 1);

    c.onAppResumed(); // last sync just now: below the threshold
    await settle();
    expect(engine.runs, before + 1);
    await settle(150);
    c.onAppResumed();
    await settle();
    expect(engine.runs, before + 2);
  });

  test('Wi-Fi only gates automatic syncs, not manual ones', () async {
    connectivity.wifi = false;
    final c = controller(wifiOnly: true);
    await c.onLockStateChanged(AppLockState.unlocked);
    await localChange('p1');
    await settle(200);
    expect(engine.runs, 0);
    await c.syncNow();
    expect(engine.runs, 1);

    connectivity.connected = false;
    await c.syncNow();
    expect(engine.runs, 1, reason: 'offline: nothing to do');
  });

  test('errors never escape as unhandled', () async {
    final unhandled = <Object>[];
    await runZonedGuarded(() async {
      engine.error = const SyncException('boom', retryable: true);
      final c = controller(interval: const Duration(milliseconds: 40));
      await c.onLockStateChanged(AppLockState.unlocked);
      await localChange('p1');
      connectivity.controller.add(ConnectionStatus.offline);
      connectivity.controller.add(ConnectionStatus.online);
      await settle(200);
      expect(c.state.status, SyncStatus.error);
      expect(c.state.errorMessage, 'boom');
      engine.error = StateError('unexpected');
      await c.syncNow();
      await settle(100);
      expect(c.state.status, SyncStatus.error);
      engine.error = null;
      await c.syncNow();
      expect(c.state.status, SyncStatus.connected);
      expect(c.state.errorMessage, isNull);
    }, (error, _) => unhandled.add(error));
    expect(unhandled, isEmpty);
    expect(engine.runs, greaterThan(2));
  });

  test('pending changes, conflicts and quarantine are exposed', () async {
    final c = controller(frequency: SyncFrequency.manual);
    await c.onLockStateChanged(AppLockState.unlocked);
    await localChange('p1');
    await settle(100);
    expect(c.state.pendingChanges, greaterThan(0));
    await t.db.syncDao.addConflict(
      SyncConflictsCompanion.insert(
        syncTable: 'payees',
        rowId: 'p1',
        localSnapshot: const Value('{"id":"p1"}'),
        remoteDeviceId: 'x',
        resolvedAt: DateTime.utc(2030),
      ),
    );
    await t.db.syncDao.putQuarantine(
      SyncQuarantineCompanion.insert(
        filename: 'f',
        deviceId: 'd',
        sequence: 1,
        reason: 'newer_schema',
        error: 'e',
        firstSeen: DateTime.utc(2030),
        lastAttempt: DateTime.utc(2030),
        nextAttempt: DateTime.utc(2030),
      ),
    );
    await settle(100);
    expect(c.state.conflicts, hasLength(1));
    expect(c.state.newerSchemaPending, isTrue);
    expect(c.quarantineDiagnostics(), contains('newer_schema'));
    await c.dismissConflict(c.state.conflicts.single.id);
    await settle(100);
    expect(c.state.conflicts, isEmpty);
  });

  test('a provider saved by an older version (iCloud) means no sync', () async {
    final c = controller(provider: 'iCloud');
    expect(c.state.selectedProvider, SyncProviderType.none);
    await c.onLockStateChanged(AppLockState.unlocked);
    await localChange('p1');
    await c.syncNow();
    await settle(100);
    expect(engine.runs, 0);
    expect(c.state.status, isNot(SyncStatus.error));
  });
}
