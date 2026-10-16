import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/widgets/security/password_strength_meter.dart';
import 'package:ledger_zero/presentation/widgets/security/recovery_key_view.dart';
import 'package:ledger_zero/services/security/biometric_key_store.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/external_ui_guard.dart';
import 'package:ledger_zero/services/security/key_vault.dart';

/// Onboarding step 1: master password, then the recovery key.
///
/// Nothing is written until the user confirms the recovery key is saved:
/// then the key vault is stored, any half-created database from an earlier
/// attempt is removed, and the session is unlocked with the new data key.
class SecuritySetupScreen extends ConsumerStatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  ConsumerState<SecuritySetupScreen> createState() =>
      _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends ConsumerState<SecuritySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isBiometricsAvailable = false;
  bool _useBiometrics = false;
  bool _isLoading = false;
  bool _recoveryKeySaved = false;
  PendingVault? _pending;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await ref.read(biometricKeyStoreProvider).isAvailable();
    if (mounted) {
      setState(() {
        _isBiometricsAvailable = available;
        _useBiometrics = available;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    final pending = _pending;
    if (pending != null) {
      zeroBytes(pending.dek);
      pending.recoveryKey.destroy();
    }
    super.dispose();
  }

  Future<void> _buildVault() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final pending = await ref
          .read(keyVaultProvider)
          .build(_passwordController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _pending = pending;
        _isLoading = false;
      });
    } catch (_) {
      _fail();
    }
  }

  Future<void> _commit() async {
    final pending = _pending;
    if (pending == null || !_recoveryKeySaved) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await ref.read(sessionProvider.notifier).lock();
      // A database left by an abandoned earlier onboarding is keyed with a
      // key that no longer exists.
      await deleteDatabaseFiles();
      await ref.read(keyVaultProvider).save(pending.record);
      await ref.read(legacyKeyMaterialProvider).deleteAll();
      final biometrics = ref.read(biometricKeyStoreProvider);
      await biometrics.delete();
      ref.read(sessionProvider.notifier).unlock(pending.dek);

      if (_useBiometrics) {
        try {
          await ExternalUiGuard.run(
            () => biometrics.store(
              pending.dek,
              BiometricPromptTexts(
                title: l10n.biometricPromptEnableTitle,
                subtitle: l10n.biometricPromptSubtitle,
                cancel: l10n.cancel,
              ),
            ),
          );
        } on BiometricException {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.biometricsEnableFailed)),
          );
        }
      }
    } catch (_) {
      // Start over from the password step with fresh keys.
      _pending = null;
      _recoveryKeySaved = false;
      _fail();
      return;
    } finally {
      zeroBytes(pending.dek);
      pending.recoveryKey.destroy();
    }
    _pending = null;
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.goNamed('budget-setup');
      }
    });
  }

  void _fail() {
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.setupFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pending = _pending;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.setupProtectTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: pending == null
              ? _buildPasswordStep(l10n)
              : _buildRecoveryStep(l10n, pending),
        ),
      ),
    );
  }

  Widget _buildPasswordStep(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.setupPasswordHeading,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(l10n.setupPasswordExplanation),
          const SizedBox(height: 32),
          NewPasswordFields(
            controller: _passwordController,
            confirmController: _confirmPasswordController,
            label: l10n.masterPasswordLabel,
            onSubmitted: _isLoading ? null : _buildVault,
          ),
          const SizedBox(height: 24),
          if (_isBiometricsAvailable) ...[
            SwitchListTile(
              title: Text(l10n.setupUseBiometrics),
              subtitle: Text(l10n.setupUseBiometricsSubtitle),
              value: _useBiometrics,
              onChanged: (value) => setState(() => _useBiometrics = value),
            ),
            const SizedBox(height: 24),
          ],
          ElevatedButton(
            onPressed: _isLoading ? null : _buildVault,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.setupPreparing),
                    ],
                  )
                : Text(l10n.continueAction),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryStep(AppLocalizations l10n, PendingVault pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.recoveryKeyHeading,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(l10n.recoveryKeyExplanation),
        const SizedBox(height: 24),
        RecoveryKeyView(formattedKey: pending.recoveryKey.format()),
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
          onPressed: _isLoading || !_recoveryKeySaved ? null : _commit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.continueAction),
        ),
      ],
    );
  }
}
