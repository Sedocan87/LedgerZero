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
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
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
    SharedPreferences.setMockInitialValues({
      kAutoLockDurationKey: 0,
      kAppLockEnabledKey: true,
      'user_onboarded': true,
    });
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  test('closed: there is no database, not even an unkeyed one', () {
    expect(
      () => container.read(databaseProvider),
      throwsA(isA<DatabaseLockedException>()),
    );
    expect(container.read(appLockStateProvider), AppLockState.locked);
  });

  test(
    'open opens a keyed database; close closes it and zeroes the key',
    () async {
      final states = <AppLockState>[];
      container.listen(
        appLockStateProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );

      final dek = secureRandomBytes(32);
      container.read(sessionProvider.notifier).open(dek);
      await pumpEventQueue();
      // The session is independent of the UI lock.
      expect(container.read(authProvider).isAuthenticated, isFalse);

      final db = container.read(databaseProvider);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(id: 'a', name: 'A', type: 'checking'),
          );
      final key = container.read(sessionProvider).key!;

      await container.read(sessionProvider.notifier).close();
      await pumpEventQueue();

      expect(states, [
        AppLockState.locked,
        AppLockState.unlocked,
        AppLockState.locked,
      ]);
      expect(key.isDestroyed, isTrue);
      // The old connection is closed.
      await expectLater(db.select(db.accounts).get(), throwsA(anything));
      expect(
        () => container.read(databaseProvider),
        throwsA(isA<DatabaseLockedException>()),
      );

      // Opening again with the same key reopens the same data.
      container.read(sessionProvider.notifier).open(dek);
      final reopened = container.read(databaseProvider);
      expect((await reopened.select(reopened.accounts).get()).single.id, 'a');
      await container.read(sessionProvider.notifier).close();
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

    bool uiLocked() => !container.read(authProvider).isAuthenticated;

    setUp(() {
      now = DateTime.utc(2026, 1, 1, 12);
      container.read(sessionProvider.notifier).open(secureRandomBytes(32));
      container.read(authProvider.notifier).setAuthenticated(true);
    });

    test('immediate mode locks as soon as the app becomes inactive', () async {
      final service = buildService(Stopwatch());
      service.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await pumpEventQueue();
      expect(uiLocked(), isTrue);
      // Only the UI: the database stays open for sync and card capture.
      expect(container.read(appLockStateProvider), AppLockState.unlocked);
      service.dispose();
    });

    test('with the app lock off nothing locks', () async {
      await container.read(appLockEnabledProvider.notifier).set(false);
      final service = buildService(Stopwatch());
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(uiLocked(), isFalse);
      service.dispose();
    });

    test('nothing locks before onboarding is finished', () async {
      container.read(authProvider.notifier).setOnboarded(false);
      final service = buildService(Stopwatch());
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(uiLocked(), isFalse);
      service.dispose();
    });

    test('OS screens opened by the app do not lock', () async {
      final service = buildService(Stopwatch());
      await ExternalUiGuard.run(() async {
        service.didChangeAppLifecycleState(AppLifecycleState.inactive);
        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        expect(uiLocked(), isFalse);
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });
      await pumpEventQueue();
      expect(uiLocked(), isFalse);
      service.dispose();
    });

    test('if the app is still in the background after the OS screen closed '
        '(and the grace period), it locks', () async {
      void Function()? grace;
      final service = buildService(
        Stopwatch(),
        timerFactory: (duration, callback) {
          expect(duration, AutoLockService.resumeGrace);
          grace = callback;
          return Timer(const Duration(days: 1), () {});
        },
      );
      await ExternalUiGuard.run(() async {
        service.didChangeAppLifecycleState(AppLifecycleState.paused);
      });
      await pumpEventQueue();
      expect(uiLocked(), isFalse);
      grace!();
      await pumpEventQueue();
      expect(uiLocked(), isTrue);
      service.dispose();
    });

    test('a full-screen OS prompt that reports before the app resumes does not '
        'lock (device PIN screen of the app lock)', () async {
      void Function()? grace;
      final service = buildService(
        Stopwatch(),
        timerFactory: (duration, callback) {
          grace = callback;
          return Timer(const Duration(days: 1), () {});
        },
      );
      await ExternalUiGuard.run(() async {
        service.didChangeAppLifecycleState(AppLifecycleState.paused);
      });
      // The result arrived; `resumed` follows a moment later.
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      grace?.call();
      await pumpEventQueue();
      expect(uiLocked(), isFalse);
      service.dispose();
    });

    test(
      'timeout mode: locks on resume after the timeout, not before',
      () async {
        await container.read(autoLockDurationProvider.notifier).setDuration(5);
        final service = buildService(Stopwatch());

        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 4));
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(uiLocked(), isFalse);

        service.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 6));
        service.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(uiLocked(), isTrue);
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
      expect(uiLocked(), isTrue);
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
      expect(uiLocked(), isFalse);
      fire!();
      await pumpEventQueue();
      expect(uiLocked(), isTrue);
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
