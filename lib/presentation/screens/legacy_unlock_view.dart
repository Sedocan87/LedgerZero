import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/unlock_service.dart';

enum _Step { password, recoveryKey }

/// One-time unlock of an install from before the device key: the master
/// password, the old biometric key or the recovery key recover the data
/// key, which [onUnlocked] then moves to the device key store (see
/// `LegacyKeyMigration`). After that the password is not needed any more.
class LegacyUnlockView extends ConsumerStatefulWidget {
  const LegacyUnlockView({
    super.key,
    required this.onUnlocked,
    required this.onReset,
  });

  /// Receives the recovered data key (the callee zeroes it).
  final Future<void> Function(Uint8List dek) onUnlocked;

  /// The vault is gone: offer a factory reset.
  final VoidCallback onReset;

  @override
  ConsumerState<LegacyUnlockView> createState() => _LegacyUnlockViewState();
}

class _LegacyUnlockViewState extends ConsumerState<LegacyUnlockView> {
  final _passwordController = TextEditingController();
  final _recoveryController = TextEditingController();

  _Step _step = _Step.password;
  bool _isLoading = false;
  bool _isBiometricsAvailable = false;
  bool _isPasswordVisible = false;

  /// The key vault is gone: nothing can unlock the data any more, so the
  /// only way forward is a reset (then restoring a backup).
  bool _vaultMissing = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _recoveryController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final store = ref.read(biometricKeyStoreProvider);
    final available = await store.isAvailable() && await store.hasKey();
    if (mounted) {
      setState(() => _isBiometricsAvailable = available);
    }
  }

  Future<void> _unlock(Future<Uint8List> Function() recover) async {
    if (_isLoading) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final dek = await recover();
      await widget.onUnlocked(dek);
    } on BiometricException catch (e) {
      switch (e.failure) {
        case BiometricFailure.cancelled:
          break;
        case BiometricFailure.invalidated:
        case BiometricFailure.notFound:
          setState(() => _isBiometricsAvailable = false);
          _showError(l10n.biometricsInvalidated);
        case BiometricFailure.unavailable:
        case BiometricFailure.failed:
          _showError(l10n.biometricsUnlockFailed);
      }
    } on VaultMissingException {
      if (mounted) {
        setState(() => _vaultMissing = true);
      }
    } catch (e) {
      _showError(_messageFor(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _withPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      return;
    }
    await _unlock(() async {
      final result = await ref
          .read(unlockServiceProvider)
          .unlockWithPassword(password);
      _passwordController.clear();
      // A pre-v2 install gets a new recovery key from the migration; it is
      // not needed any more.
      result.newRecoveryKey?.destroy();
      return result.dek;
    });
  }

  Future<void> _withRecoveryKey() async {
    final typed = _recoveryController.text;
    if (typed.trim().isEmpty) {
      return;
    }
    await _unlock(() async {
      final dek = await ref
          .read(unlockServiceProvider)
          .unlockWithRecoveryKey(typed);
      _recoveryController.clear();
      return dek;
    });
  }

  Future<void> _withBiometrics() {
    final l10n = AppLocalizations.of(context)!;
    return _unlock(
      () => ExternalUiGuard.run(
        () => ref
            .read(unlockServiceProvider)
            .unlockWithBiometrics(
              BiometricPromptTexts(
                title: l10n.biometricPromptTitle,
                subtitle: l10n.biometricPromptSubtitle,
                cancel: l10n.cancel,
              ),
            ),
      ),
    );
  }

  String _messageFor(AppLocalizations l10n, Object error) {
    return switch (error) {
      WrongPasswordException() => l10n.incorrectPassword,
      InvalidRecoveryKeyException() => l10n.recoveryKeyInvalid,
      LegacyMigrationPendingException() => l10n.recoveryKeyNeedsPassword,
      DatabaseKeyException() => l10n.loginDatabaseKeyMismatch,
      _ => l10n.loginFailed,
    };
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _progressOr(Widget child) => _isLoading
      ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_step) {
      _Step.password => _buildPassword(l10n),
      _Step.recoveryKey => _buildRecoveryKey(l10n),
    };
  }

  Widget _buildPassword(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline, size: 64, color: Colors.teal),
        const SizedBox(height: 32),
        Text(
          l10n.legacyUnlockTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(l10n.legacyUnlockExplanation, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.masterPasswordLabel,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _isPasswordVisible
                  ? l10n.hidePassword
                  : l10n.showPassword,
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
          onSubmitted: (_) => _withPassword(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _withPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _progressOr(Text(l10n.loginUnlock)),
        ),
        if (_isBiometricsAvailable) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _isLoading ? null : _withBiometrics,
            icon: const Icon(Icons.fingerprint),
            label: Text(l10n.loginUseBiometrics),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() => _step = _Step.recoveryKey),
          child: Text(l10n.loginUseRecoveryKey),
        ),
        if (_vaultMissing) ...[
          const SizedBox(height: 24),
          Text(
            l10n.loginVaultMissing,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('login_reset_app'),
            onPressed: _isLoading ? null : widget.onReset,
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.loginResetApp),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecoveryKey(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.recoveryKeyEnterTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _recoveryController,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          maxLines: 2,
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1),
          decoration: InputDecoration(
            helperText: l10n.recoveryKeyEnterHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _withRecoveryKey(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _withRecoveryKey,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _progressOr(Text(l10n.loginUnlock)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() {
                  _recoveryController.clear();
                  _step = _Step.password;
                }),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
