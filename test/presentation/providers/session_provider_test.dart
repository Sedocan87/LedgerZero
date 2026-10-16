import 'dart:io';

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/security/auto_lock_service.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('lz_session_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    SharedPreferences.setMockInitialValues({kAutoLockDurationKey: 0});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  test('locked: there is no database, not even an unkeyed one', () {
    expect(
      () => container.read(databaseProvider),
      throwsA(isA<DatabaseLockedException>()),
    );
    expect(container.read(appLockStateProvider), AppLockState.locked);
  });

  test(
    'unlock opens a keyed database; lock closes it and zeroes the key',
    () async {
      final states = <AppLockState>[];
      container.listen(
        appLockStateProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      final dek = secureRandomBytes(32);
      container.read(sessionProvider.notifier).unlock(dek);
      await pumpEventQueue();
      expect(container.read(authProvider).isAuthenticated, isTrue);

      final db = container.read(databaseProvider);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(id: 'a', name: 'A', type: 'checking'),
          );
      final key = container.read(sessionProvider).key!;

      await container.read(sessionProvider.notifier).lock();
      await pumpEventQueue();

      expect(states, [
        AppLockState.locked,
        AppLockState.unlocked,
        AppLockState.locked,
      ]);
      expect(key.isDestroyed, isTrue);
      expect(container.read(authProvider).isAuthenticated, isFalse);
      // The old connection is closed.
      await expectLater(db.select(db.accounts).get(), throwsA(anything));
      expect(
        () => container.read(databaseProvider),
        throwsA(isA<DatabaseLockedException>()),
      );

      // Unlocking again with the same key reopens the same data.
      container.read(sessionProvider.notifier).unlock(dek);
      final reopened = container.read(databaseProvider);
      expect((await reopened.select(reopened.accounts).get()).single.id, 'a');
      await container.read(sessionProvider.notifier).lock();
    },
  );

  group('AutoLockService', () {
    late DateTime now;

    AutoLockService buildService(
      Stopwatch stopwatch, {
      Timer Function(Duration, void Function())? timerFactory,
    }) {
      final ref = container.read(_refProvider);
      return AutoLockService(
        ref,
        now: () => now,
        stopwatch: stopwatch,
        timerFactory: timerFactory,
      );
    }

    setUp(() {
      now = DateTime.utc(2026, 1, 1, 12);
      container.read(sessionProvider.notifier).unlock(secureRandomBytes(32));
    });

    test('immediate mode locks as soon as the app becomes inactive', () async {
      final service = buildService(Stopwatch());
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();
      expect(container.read(appLockStateProvider), AppLockState.locked);
      service.dispose();
    });

    test('OS screens opened by the app do not lock', () async {
      final service = buildService(Stopwatch());
      await ExternalUiGuard.run(() async {
        service.didChangeAppLifecycleState(AppLifecycleState.inactive);
        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        expect(container.read(appLockStateProvider), AppLockState.unlocked);
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });
      await pumpEventQueue();
      expect(container.read(appLockStateProvider), AppLockState.unlocked);
      service.dispose();
    });

    test(
      'if the app is still in the background when the OS screen closes, it locks',
      () async {
        final service = buildService(Stopwatch());
        await ExternalUiGuard.run(() async {
          service.didChangeAppLifecycleState(AppLifecycleState.paused);
        });
        await pumpEventQueue();
        expect(container.read(appLockStateProvider), AppLockState.locked);
        service.dispose();
      },
    );

    test(
      'timeout mode: locks on resume after the timeout, not before',
      () async {
        await container.read(autoLockDurationProvider.notifier).setDuration(5);
        final service = buildService(Stopwatch());

        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 4));
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(container.read(appLockStateProvider), AppLockState.unlocked);

        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 6));
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(container.read(appLockStateProvider), AppLockState.locked);
        service.dispose();
      },
    );

    test('moving the wall clock back does not extend the session', () async {
      await container.read(autoLockDurationProvider.notifier).setDuration(5);
      final stopwatch = _FakeStopwatch();
      final service = buildService(stopwatch);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      stopwatch.fakeElapsed = const Duration(minutes: 6);
      now = now.subtract(const Duration(hours: 1));
      expect(service.elapsedInBackground, const Duration(minutes: 6));
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(container.read(appLockStateProvider), AppLockState.locked);
      service.dispose();
    });

    test('a timer locks while the app stays in the background', () async {
      await container.read(autoLockDurationProvider.notifier).setDuration(1);
      Duration? scheduled;
      void Function()? fire;
      final service = buildService(
        Stopwatch(),
        timerFactory: (duration, callback) {
          scheduled = duration;
          fire = callback;
          return Timer(const Duration(days: 1), () {});
        },
      );
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(scheduled, const Duration(minutes: 1));
      expect(container.read(appLockStateProvider), AppLockState.unlocked);
      fire!();
      await pumpEventQueue();
      expect(container.read(appLockStateProvider), AppLockState.locked);
      service.dispose();
    });
  });
}

final _refProvider = Provider<Ref>((ref) => ref);

class _FakeStopwatch implements Stopwatch {
  Duration fakeElapsed = Duration.zero;

  @override
  Duration get elapsed => fakeElapsed;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
