import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/encryption/security_manager.dart';

class BiometricsState {
  final bool isAvailable;
  final bool isEnabled;

  const BiometricsState({
    required this.isAvailable,
    required this.isEnabled,
  });
}

class BiometricsNotifier extends StateNotifier<AsyncValue<BiometricsState>> {
  final SecurityManager _securityManager;

  BiometricsNotifier(this._securityManager) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final available = await _securityManager.isBiometricsAvailable;
      final enabled = await _securityManager.hasKey();
      state = AsyncValue.data(BiometricsState(
        isAvailable: available,
        isEnabled: enabled,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> toggleBiometrics(bool enable) async {
    try {
      // Check availability again just in case
      final available = await _securityManager.isBiometricsAvailable;
      if (!available) {
         // Cannot enable if not available
         state = const AsyncValue.data(BiometricsState(isAvailable: false, isEnabled: false));
         return false;
      }

      if (enable) {
        // Must authenticate to enable
        final authenticated = await _securityManager.authenticateWithBiometrics();
        if (authenticated) {
           final sessionKey = SecurityManager.sessionKey;
           if (sessionKey != null) {
             await _securityManager.storeKey(sessionKey);
             state = const AsyncValue.data(BiometricsState(
               isAvailable: true,
               isEnabled: true,
             ));
             return true;
           }
        }
        // Auth failed or session key missing
        return false;
      } else {
        // Disable
        await _securityManager.clearKey();
        state = const AsyncValue.data(BiometricsState(
           isAvailable: true,
           isEnabled: false,
        ));
        return true;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final biometricsProvider = StateNotifierProvider<BiometricsNotifier, AsyncValue<BiometricsState>>((ref) {
  final sm = ref.watch(securityManagerProvider);
  return BiometricsNotifier(sm);
});
