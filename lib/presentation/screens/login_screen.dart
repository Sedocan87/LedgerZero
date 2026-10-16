import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/data/database/sqlcipher.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/factory_reset_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/widgets/security/password_strength_meter.dart';
import 'package:ledger_zero/presentation/widgets/security/recovery_key_view.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/crypto/recovery_key.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:ledger_zero/services/security/key_vault.dart';
import 'package:ledger_zero/services/security/unlock_service.dart';

enum _LoginStep { password, recoveryKey, newPassword, showRecoveryKey }

/// Unlocks the data key with the password, biometrics or the recovery key.
///
/// A recovery-key unlock must set a new password before the app opens. The
/// first password unlock after the legacy migration shows the new recovery
/// key and asks the user to confirm it was saved.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _passwordController = TextEditingController();
  final _recoveryController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFormKey = GlobalKey<FormState>();

  _LoginStep _step = _LoginStep.password;
  bool _isLoading = false;
  bool _isBiometricsAvailable = false;
  bool _isPasswordVisible = false;
  bool _recoveryKeySaved = false;

  /// Unwrapped data key held between steps; zeroed on use or dispose.
  Uint8List? _pendingDek;
  RecoveryKey? _newRecoveryKey;
  bool _biometricsWereReset = false;

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
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    zeroBytes(_pendingDek);
    _newRecoveryKey?.destroy();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final store = ref.read(biometricKeyStoreProvider);
    final available = await store.isAvailable() && await store.hasKey();
    if (!mounted) {
      return;
    }
    setState(() => _isBiometricsAvailable = available);
    if (available) {
      await _loginWithBiometrics();
    }
  }

  BiometricPromptTexts _promptTexts(AppLocalizations l10n) =>
      BiometricPromptTexts(
        title: l10n.biometricPromptTitle,
        subtitle: l10n.biometricPromptSubtitle,
        cancel: l10n.cancel,
      );

  Future<void> _loginWithBiometrics() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final dek = await ExternalUiGuard.run(
        () => ref
            .read(unlockServiceProvider)
            .unlockWithBiometrics(_promptTexts(l10n)),
      );
      _finish(dek);
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
    } catch (e) {
      _showUnlockError(l10n, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty || _isLoading) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(unlockServiceProvider)
          .unlockWithPassword(password);
      _passwordController.clear();
      if (result.newRecoveryKey != null) {
        setState(() {
          _pendingDek = result.dek;
          _newRecoveryKey = result.newRecoveryKey;
          _biometricsWereReset = result.biometricsWereReset;
          _step = _LoginStep.showRecoveryKey;
        });
        return;
      }
      _finish(result.dek);
    } catch (e) {
      _showUnlockError(l10n, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithRecoveryKey() async {
    final typed = _recoveryController.text;
    if (typed.trim().isEmpty || _isLoading) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final dek = await ref
          .read(unlockServiceProvider)
          .unlockWithRecoveryKey(typed);
      _recoveryController.clear();
      setState(() {
        _pendingDek = dek;
        _step = _LoginStep.newPassword;
      });
    } catch (e) {
      _showUnlockError(l10n, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setNewPassword() async {
    final dek = _pendingDek;
    if (dek == null || !_newPasswordFormKey.currentState!.validate()) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(keyVaultProvider)
          .setPassword(dek: dek, newPassword: _newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _pendingDek = null;
      _finish(dek);
    } catch (e) {
      _showUnlockError(l10n, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmRecoveryKeySaved() {
    final dek = _pendingDek;
    if (dek == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    _pendingDek = null;
    _newRecoveryKey?.destroy();
    _newRecoveryKey = null;
    _finish(dek);
    if (_biometricsWereReset) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.migrationBiometricsReset)),
      );
    }
  }

  void _finish(Uint8List dek) {
    ref.read(sessionProvider.notifier).unlock(dek);
    zeroBytes(dek);
    if (mounted) {
      context.go('/');
    }
  }

  String _messageFor(AppLocalizations l10n, Object error) {
    return switch (error) {
      WrongPasswordException() => l10n.incorrectPassword,
      InvalidRecoveryKeyException() => l10n.recoveryKeyInvalid,
      LegacyMigrationPendingException() => l10n.recoveryKeyNeedsPassword,
      VaultMissingException() => l10n.loginVaultMissing,
      DatabaseKeyException() => l10n.loginDatabaseKeyMismatch,
      _ => l10n.loginFailed,
    };
  }

  /// Shows the error of a failed unlock; a missing key vault switches the
  /// screen to the reset state.
  void _showUnlockError(AppLocalizations l10n, Object error) {
    if (error is VaultMissingException) {
      // Shown inline together with the reset action instead.
      if (mounted) {
        setState(() => _vaultMissing = true);
      }
      return;
    }
    _showError(_messageFor(l10n, error));
  }

  /// Factory reset from the locked screen, behind a typed confirmation word.
  Future<void> _resetApp() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetAppDialog(l10n: l10n),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(factoryResetServiceProvider).reset();
      if (mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      _showError(l10n.loginFailed);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: switch (_step) {
              _LoginStep.password => _buildPassword(l10n),
              _LoginStep.recoveryKey => _buildRecoveryKey(l10n),
              _LoginStep.newPassword => _buildNewPassword(l10n),
              _LoginStep.showRecoveryKey => _buildShowRecoveryKey(l10n),
            },
          ),
        ),
      ),
    );
  }

  Widget _progressOr(Widget child) => _isLoading
      ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : child;

  Widget _buildPassword(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline, size: 64, color: Colors.teal),
        const SizedBox(height: 32),
        Text(
          l10n.loginTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
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
          onSubmitted: (_) => _loginWithPassword(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _loginWithPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _progressOr(Text(l10n.loginUnlock)),
        ),
        if (_isBiometricsAvailable) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _isLoading ? null : _loginWithBiometrics,
            icon: const Icon(Icons.fingerprint),
            label: Text(l10n.loginUseBiometrics),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => setState(() => _step = _LoginStep.recoveryKey),
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
            onPressed: _isLoading ? null : _resetApp,
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
          onSubmitted: (_) => _loginWithRecoveryKey(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _loginWithRecoveryKey,
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
                  _step = _LoginStep.password;
                }),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildNewPassword(AppLocalizations l10n) {
    return Form(
      key: _newPasswordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setNewPasswordTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(l10n.setNewPasswordExplanation),
          const SizedBox(height: 24),
          NewPasswordFields(
            controller: _newPasswordController,
            confirmController: _confirmPasswordController,
            label: l10n.newPassword,
            onSubmitted: _isLoading ? null : _setNewPassword,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _setNewPassword,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _progressOr(Text(l10n.continueAction)),
          ),
        ],
      ),
    );
  }

  Widget _buildShowRecoveryKey(AppLocalizations l10n) {
    final key = _newRecoveryKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.recoveryKeyHeading,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(l10n.migrationRecoveryKeyExplanation),
        const SizedBox(height: 8),
        Text(l10n.recoveryKeyExplanation),
        const SizedBox(height: 24),
        if (key != null) RecoveryKeyView(formattedKey: key.format()),
        const SizedBox(height: 24),
        CheckboxListTile(
          value: _recoveryKeySaved,
          onChanged: (value) =>
              setState(() => _recoveryKeySaved = value ?? false),
          title: Text(l10n.recoveryKeyConfirmSaved),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _recoveryKeySaved ? _confirmRecoveryKeySaved : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(l10n.continueAction),
        ),
      ],
    );
  }
}

/// Confirmation for the reset from the login screen: the reset button is
/// enabled only after typing the localised confirmation word.
class _ResetAppDialog extends StatefulWidget {
  const _ResetAppDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_ResetAppDialog> createState() => _ResetAppDialogState();
}

class _ResetAppDialogState extends State<_ResetAppDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _confirmed =>
      _controller.text.trim().toUpperCase() ==
      widget.l10n.loginResetConfirmWord.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.loginResetAppTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.loginResetAppBody(l10n.loginResetConfirmWord)),
            const SizedBox(height: 16),
            TextField(
              key: const Key('login_reset_confirm_field'),
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.loginResetConfirmLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('login_reset_confirm'),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: Text(l10n.loginResetApp),
        ),
      ],
    );
  }
}
