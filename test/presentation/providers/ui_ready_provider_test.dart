// uiReadyProvider gates what MyApp does on unlock (notification permission
// prompt, pending notification taps): never mid-onboarding.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer c;

  /// How often the UI became ready, as MyApp counts it (false -> true).
  late int becameReady;

  Future<void> start({required bool onboarded}) async {
    SharedPreferences.setMockInitialValues({'user_onboarded': onboarded});
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    becameReady = 0;
    c.listen<bool>(uiReadyProvider, (previous, next) {
      if (next && previous != true) {
        becameReady++;
      }
    });
  }

  /// Applies [change] and lets the dependent provider (and its listener)
  /// update, as the next frame would; returns the readiness.
  bool after(void Function(AuthNotifier auth) change) {
    change(c.read(authProvider.notifier));
    return c.read(uiReadyProvider);
  }

  test('mid-onboarding the open session is not "ready"; the end of '
      'onboarding is', () async {
    await start(onboarded: false);
    // The security step opens the session and the UI.
    expect(after((a) => a.setAuthenticated(true)), isFalse);
    expect(becameReady, 0);
    // The first account is saved.
    expect(after((a) => a.setOnboarded(true)), isTrue);
    expect(becameReady, 1);
  });

  test('an onboarded app is ready at each unlock', () async {
    await start(onboarded: true);
    expect(c.read(uiReadyProvider), isFalse);
    expect(after((a) => a.setAuthenticated(true)), isTrue);
    expect(becameReady, 1);
    expect(after((a) => a.setAuthenticated(false)), isFalse);
    expect(after((a) => a.setAuthenticated(true)), isTrue);
    expect(becameReady, 2);
  });

  test('after a factory reset the unlocked UI is not ready', () async {
    await start(onboarded: true);
    expect(after((a) => a.setAuthenticated(true)), isTrue);
    expect(
      after(
        (a) => a
          ..setAuthenticated(false)
          ..setOnboarded(false),
      ),
      isFalse,
    );
    expect(after((a) => a.setAuthenticated(true)), isFalse);
    expect(becameReady, 1);
  });
}
