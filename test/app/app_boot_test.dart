import 'dart:async';
import 'dart:convert';
// Boot smoke test of the whole app widget (MyApp): the first launch opens
// the onboarding, a returning user the login screen. Router details are in
// test/presentation/router/app_router_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/presentation/providers/notification_providers.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/new_month_fill_provider.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_state.dart';
import 'package:ledger_zero/presentation/providers/sync_providers.dart';
import 'package:ledger_zero/services/sync/sync_conflict_resolver.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
import 'package:ledger_zero/services/notifications/local_notifications_client.dart';
import 'package:ledger_zero/services/notifications/notification_service.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/device_key_store.dart';
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers/security_fakes.dart';
import '../presentation/providers/sync_controller_lifecycle_test.dart'
    show DummyTransport, FakeAuth, FakeConnectivity, FakeEngine;

/// Counts catch-up runs; books nothing.
class _RecordingSchedules extends Fake implements ScheduledTransactionService {
  int runs = 0;
  int finished = 0;
  Completer<void>? gate;

  @override
  Future<int> processDueTransactions({
    String? fallbackMemo,
    DateTime? today,
  }) async {
    runs++;
    await gate?.future;
    finished++;
    return 0;
  }

  @override
  Future<void> rescheduleReminders() async {}
}

/// Counts permission requests; shows nothing.
class _CountingNotificationsClient implements LocalNotificationsClient {
  int permissionRequests = 0;

  @override
  Future<void> initialize(
    InitializationSettings settings, {
    required void Function(String? payload) onTap,
  }) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<void> show(
    int id,
    String title,
    String body,
    NotificationDetails details, {
    String? payload,
  }) async {}

  @override
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    tz.TZDateTime scheduledDate,
    NotificationDetails details, {
    String? payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> requestPermissions() async => permissionRequests++;
}

/// Counts fill runs and whether every catch-up started so far had ended.
class _RecordingFill extends NewMonthFillController {
  _RecordingFill(SharedPreferences prefs, this._schedules)
    : super(prefs, () => throw StateError('not used'));

  final _RecordingSchedules _schedules;
  int runs = 0;
  final bookedBefore = <bool>[];

  @override
  Future<void> runIfDue() async {
    runs++;
    bookedBefore.add(_schedules.finished == _schedules.runs);
  }
}

void main() {
  late Directory dir;
  late _CountingNotificationsClient notifications;

  setUpAll(() {
    try {
      AppConfig(environment: AppEnvironment.development, appTitle: 'Test');
    } catch (_) {
      // Already initialised by another test in this isolate.
    }
  });

  setUp(() {
    notifications = _CountingNotificationsClient();
    dir = Directory.systemTemp.createTempSync('lz_boot_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> boot(
    WidgetTester tester,
    Map<String, Object> prefs, {
    Map<String, String>? secrets,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sharedPreferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          secureStoreProvider.overrideWithValue(InMemorySecureStore(secrets)),
          appLockAuthenticatorProvider.overrideWithValue(
            FakeAppLockAuthenticator(result: AppLockResult.cancelled),
          ),
          legacySecureStoreProvider.overrideWithValue(InMemorySecureStore()),
          biometricKeyStoreProvider.overrideWithValue(
            FakeBiometricKeyStore(available: false),
          ),
          notificationServiceProvider.overrideWithValue(
            NotificationService(client: notifications),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first launch shows the onboarding', (tester) async {
    await boot(tester, {});
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('LedgerZero'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'UI text and the formatter resolve the same locale from the device list',
    (tester) async {
      // French first (unsupported), then German: the UI is German, so the
      // formatter must be too (not English from the first locale only).
      tester.platformDispatcher.localesTestValue = const [
        Locale('fr', 'FR'),
        Locale('de', 'DE'),
      ];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await boot(tester, {});
      expect(find.text('Weiter'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)),
      );
      expect(container.read(appLocaleProvider), const Locale('de'));
      expect(container.read(appFormatterProvider).locale, 'de');
      expect(container.read(appFormatterProvider).decimalSeparator, ',');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a returning user with the app lock starts at the lock screen', (
    tester,
  ) async {
    await boot(
      tester,
      {'user_onboarded': true, kAppLockEnabledKey: true},
      secrets: {DeviceKeyStore.storageKey: base64Encode(Uint8List(32))},
    );
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.text('LedgerZero is locked'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    // The database opened behind the lock; let its timers run out.
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('the notification permission waits for the end of onboarding', (
    tester,
  ) async {
    await boot(tester, {});
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingScreen)),
    );
    // The security step unlocks the UI mid-onboarding: no prompt over the
    // setup steps.
    container.read(authProvider.notifier).setAuthenticated(true);
    await tester.pumpAndSettle();
    expect(notifications.permissionRequests, 0);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unlock asks for the notification permission only when a '
      'notification needed it meanwhile', (tester) async {
    await boot(
      tester,
      {'user_onboarded': true, kAppLockEnabledKey: true},
      secrets: {DeviceKeyStore.storageKey: base64Encode(Uint8List(32))},
    );
    expect(notifications.permissionRequests, 0);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LockScreen)),
    );
    // Nothing to notify about: no prompt.
    container.read(authProvider.notifier).setAuthenticated(true);
    await tester.pump();
    await tester.pump();
    expect(notifications.permissionRequests, 0);

    // A notification while locked waits for the next unlock.
    container.read(authProvider.notifier).setAuthenticated(false);
    await tester.pump();
    await tester.runAsync(
      () => container
          .read(notificationServiceProvider)
          .showBackupReminderNotification(),
    );
    expect(container.read(notificationPermissionGateProvider).pending, isTrue);
    expect(notifications.permissionRequests, 0);
    container.read(authProvider.notifier).setAuthenticated(true);
    await tester.pump();
    await tester.pump();
    expect(notifications.permissionRequests, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('with sync, due schedules are booked after the first sync of '
      'the session, not when the database opens', (tester) async {
    final engine = FakeEngine()..gate = Completer<void>();
    final schedules = _RecordingSchedules();
    SharedPreferences.setMockInitialValues({
      'user_onboarded': true,
      kAppLockEnabledKey: true,
      'sync_provider': 'googleDrive',
    });
    final sharedPreferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          secureStoreProvider.overrideWithValue(
            InMemorySecureStore({
              DeviceKeyStore.storageKey: base64Encode(Uint8List(32)),
            }),
          ),
          appLockAuthenticatorProvider.overrideWithValue(
            FakeAppLockAuthenticator(result: AppLockResult.cancelled),
          ),
          legacySecureStoreProvider.overrideWithValue(InMemorySecureStore()),
          biometricKeyStoreProvider.overrideWithValue(
            FakeBiometricKeyStore(available: false),
          ),
          notificationServiceProvider.overrideWithValue(
            NotificationService(client: notifications),
          ),
          scheduledTransactionServiceProvider.overrideWithValue(schedules),
          syncControllerProvider.overrideWith((ref) {
            final controller = SyncController(
              authService: FakeAuth(),
              prefs: sharedPreferences,
              connectivity: FakeConnectivity(),
              dependencies: () => SyncDependencies(
                engineFor: (_) => engine,
                dao: ref.read(databaseProvider).syncDao,
                resolver: SyncConflictResolver(ref.read(databaseProvider)),
              ),
              transportFor: (p) =>
                  p == SyncProviderType.none ? null : DummyTransport(),
            );
            ref.listen<AppLockState>(
              appLockStateProvider,
              (_, next) => controller.onLockStateChanged(next),
              fireImmediately: true,
            );
            return controller;
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    // The database is open and the first sync is running: nothing booked.
    expect(engine.runs, 1);
    expect(schedules.runs, 0);

    engine.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(schedules.runs, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('on resume the new-month fill waits until the due schedules '
      'are booked', (tester) async {
    final schedules = _RecordingSchedules();
    SharedPreferences.setMockInitialValues({
      'user_onboarded': true,
      kAppLockEnabledKey: true,
    });
    final sharedPreferences = await SharedPreferences.getInstance();
    late _RecordingFill fill;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          secureStoreProvider.overrideWithValue(
            InMemorySecureStore({
              DeviceKeyStore.storageKey: base64Encode(Uint8List(32)),
            }),
          ),
          appLockAuthenticatorProvider.overrideWithValue(
            FakeAppLockAuthenticator(result: AppLockResult.cancelled),
          ),
          legacySecureStoreProvider.overrideWithValue(InMemorySecureStore()),
          biometricKeyStoreProvider.overrideWithValue(
            FakeBiometricKeyStore(available: false),
          ),
          notificationServiceProvider.overrideWithValue(
            NotificationService(client: notifications),
          ),
          scheduledTransactionServiceProvider.overrideWithValue(schedules),
          newMonthFillProvider.overrideWith(
            (ref) => fill = _RecordingFill(sharedPreferences, schedules),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    final runsAtStart = schedules.runs;
    final fillsAtStart = fill.runs;

    // A payday and a new month came while the app was in the background:
    // the income has to be booked before the fill looks at the money.
    schedules.gate = Completer<void>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(schedules.runs, runsAtStart + 1);
    expect(fill.runs, fillsAtStart);

    schedules.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fill.runs, fillsAtStart + 1);
    expect(fill.bookedBefore.last, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
