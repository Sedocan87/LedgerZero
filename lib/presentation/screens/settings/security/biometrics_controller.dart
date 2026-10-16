import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';

class BiometricsState {
  final bool isAvailable;
  final bool isEnabled;

  const BiometricsState({required this.isAvailable, required this.isEnabled});
}

/// Turns biometric unlock on (stores the session's data key in the
/// hardware-bound biometric store) or off (deletes it).
class BiometricsNotifier extends StateNotifier<AsyncValue<BiometricsState>> {
  final Ref _ref;
  final BiometricKeyStore _store;

  BiometricsNotifier(this._ref, this._store)
    : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final available = await _store.isAvailable();
      final enabled = await _store.hasKey();
      if (mounted) {
        state = AsyncValue.data(
          BiometricsState(isAvailable: available, isEnabled: enabled),
        );
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Returns whether the requested state was reached.
  Future<bool> toggleBiometrics(bool enable, BiometricPromptTexts texts) async {
    final available = await _store.isAvailable();
    if (!available) {
      state = const AsyncValue.data(
        BiometricsState(isAvailable: false, isEnabled: false),
      );
      return !enable;
    }
    if (!enable) {
      await _store.delete();
      state = const AsyncValue.data(
        BiometricsState(isAvailable: true, isEnabled: false),
      );
      return true;
    }
    final key = _ref.read(sessionProvider).key;
    if (key == null || key.isDestroyed) {
      return false;
    }
    try {
      await ExternalUiGuard.run(() => _store.store(key.bytes, texts));
    } on BiometricException {
      return false;
    }
    state = const AsyncValue.data(
      BiometricsState(isAvailable: true, isEnabled: true),
    );
    return true;
  }
}

final biometricsProvider =
    StateNotifierProvider.autoDispose<
      BiometricsNotifier,
      AsyncValue<BiometricsState>
    >((ref) {
      return BiometricsNotifier(ref, ref.watch(biometricKeyStoreProvider));
    });
