// Shared setup of the on-device tests: the real app (MyApp) with real
// storage — SharedPreferences, Keychain/Keystore, the SQLCipher database
// file — so what runs here is what ships. Only the system prompts are
// replaced (fingerprint/face/PIN cannot be driven on an emulator).
import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/app.dart';
import 'package:ledger_zero/core/config/app_config.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/services/security/app_lock_authenticator.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/device_key_store.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/legacy_key_material.dart';
import 'package:ledger_zero/services/security/secure_store.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometrics are not available on the test device.
class NoBiometrics implements BiometricKeyStore {
  const NoBiometrics();
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> hasKey() async => false;
  @override
  Future<Uint8List> read(BiometricPromptTexts texts) async =>
      throw const BiometricException(BiometricFailure.unavailable);
  @override
  Future<void> delete() async {}
}

/// The app lock prompt, answered with [result].
class ScriptedAppLock implements AppLockAuthenticator {
  AppLockResult result = AppLockResult.success;
  int prompts = 0;

  @override
  Future<bool> canAuthenticate() async => true;

  @override
  Future<AppLockResult> authenticate({
    required String title,
    String? subtitle,
  }) async {
    prompts++;
    return result;
  }
}

/// The app lock of the running test app (see [launchApp]).
final appLock = ScriptedAppLock();

/// Wipes everything the app stored on this device (test app sandbox only):
/// preferences, the device key, key vault and legacy key entries, database
/// files.
Future<void> resetAppData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  // The OS notification permission prompt cannot be answered from a Flutter
  // test and makes the app inactive (privacy shield) while it shows: start
  // with notifications off so the app does not ask.
  for (final key in const [
    'settings_notif_scheduled_tx',
    'settings_notif_budget_alert',
    'settings_notif_sync_status',
  ]) {
    await prefs.setBool(key, false);
  }
  final store = FlutterSecureStore.current();
  await store.delete(DeviceKeyStore.storageKey);
  await store.delete(KeyVault.storageKey);
  final legacy = FlutterSecureStore.legacy();
  for (final key in const [
    LegacyKeyMaterial.keyEntry,
    LegacyKeyMaterial.saltEntry,
    LegacyKeyMaterial.verifierEntry,
  ]) {
    await legacy.delete(key);
  }
  await deleteDatabaseFiles();
}

/// Starts the app like main_development.dart does and returns its
/// provider container.
Future<ProviderContainer> launchApp(WidgetTester tester) async {
  try {
    AppConfig(
      environment: AppEnvironment.development,
      appTitle: 'LedgerZero Test',
    );
  } catch (_) {
    // Configured by an earlier test in this run.
  }
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      biometricKeyStoreProvider.overrideWithValue(const NoBiometrics()),
      appLockAuthenticatorProvider.overrideWithValue(appLock),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pump();
  return container;
}

/// Closes the app's database and unmounts it (end of a test).
Future<void> closeApp(WidgetTester tester, ProviderContainer c) async {
  await c.read(sessionProvider.notifier).close();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 500));
  c.dispose();
}

/// Pumps frames (real time passes on a device) until [finder] matches.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure(
        'Timed out after $timeout waiting for $finder.\n'
        'Visible texts: ${visibleTexts().join(' | ')}',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Waits until [finder] no longer matches.
Future<void> waitForAbsent(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (DateTime.now().isAfter(end)) {
      throw TestFailure(
        'Timed out after $timeout; still found $finder.\n'
        'Visible texts: ${visibleTexts().join(' | ')}',
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Taps [finder] once it is there.
Future<void> tapWhenShown(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Closes a first-visit tutorial overlay if one shows up.
Future<void> dismissTutorial(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    final skip = find.text('Skip');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip.last);
      await tester.pump(const Duration(milliseconds: 500));
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Every text on screen (for failure messages).
List<String> visibleTexts() => [
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data != null) (e.widget as Text).data!,
  for (final e in find.byType(EditableText).evaluate())
    '[field] ${(e.widget as EditableText).controller.text}',
];
