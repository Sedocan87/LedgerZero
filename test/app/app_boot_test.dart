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
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
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

  testWidgets('an onboarded user is asked for the notification permission '
      'after the unlock', (tester) async {
    await boot(
      tester,
      {'user_onboarded': true, kAppLockEnabledKey: true},
      secrets: {DeviceKeyStore.storageKey: base64Encode(Uint8List(32))},
    );
    expect(notifications.permissionRequests, 0);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LockScreen)),
    );
    container.read(authProvider.notifier).setAuthenticated(true);
    await tester.pump();
    await tester.pump();
    expect(notifications.permissionRequests, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
