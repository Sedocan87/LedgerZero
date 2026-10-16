import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/widgets/security/password_strength_meter.dart';
import 'package:ledger_zero/services/security/key_vault.dart';

/// Changes the master password by re-wrapping the data key: one write of
/// the key vault, no database re-key, the recovery key stays valid.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isCurrentPasswordVisible = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(keyVaultProvider)
          .changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passwordChangedRecoveryStillValid)),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } on WrongPasswordException {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.incorrectPassword),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.changePasswordFailed),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePassword)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: !_isCurrentPasswordVisible,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.currentPassword,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _isCurrentPasswordVisible
                        ? l10n.hidePassword
                        : l10n.showPassword,
                    icon: Icon(
                      _isCurrentPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => setState(
                      () => _isCurrentPasswordVisible =
                          !_isCurrentPasswordVisible,
                    ),
                  ),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? l10n.enterPasswordPrompt
                    : null,
              ),
              const SizedBox(height: 16),
              NewPasswordFields(
                controller: _newPasswordController,
                confirmController: _confirmPasswordController,
                label: l10n.newPassword,
                onSubmitted: _isLoading ? null : _changePassword,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
