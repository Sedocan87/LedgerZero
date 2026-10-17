import 'dart:convert';
// Boot smoke test of the whole app widget (MyApp): the first launch opens
// the onboarding, a returning user the login screen. Router details are in
// test/presentation/router/app_router_test.dart.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/screens/lock_screen.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/device_key_store.dart';
import 'package:ledger_zero/presentation/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/security_fakes.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    try {
      AppConfig(environment: AppEnvironment.development, appTitle: 'Test');
    } catch (_) {
      // Already initialised by another test in this isolate.
    }
  });

  setUp(() {
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
}
