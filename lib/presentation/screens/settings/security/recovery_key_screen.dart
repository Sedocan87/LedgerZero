import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/widgets/security/recovery_key_view.dart';
import 'package:ledger_zero/services/security/crypto/recovery_key.dart';
import 'package:ledger_zero/services/security/crypto/secure_random.dart';
import 'package:ledger_zero/services/security/key_vault.dart';

/// Shows or replaces the recovery key after the user re-enters the
/// password. The key is only kept in memory while this screen is open.
class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  RecoveryKey? _recoveryKey;
  PendingRecoveryRotation? _rotation;
  bool _rotationSaved = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _recoveryKey?.destroy();
    _rotation?.recoveryKey.destroy();
    super.dispose();
  }

  Future<String?> _askPassword(AppLocalizations l10n) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmPasswordTitle),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.masterPasswordLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.confirmAction),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  /// Re-authenticates and runs [action] with the unwrapped data key.
  Future<void> _withReauth(
    Future<void> Function(KeyVault vault, Uint8List dek) action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final password = await _askPassword(l10n);
    if (password == null || password.isEmpty || !mounted) {
      return;
    }
    setState(() => _isLoading = true);
    final vault = ref.read(keyVaultProvider);
    try {
      final dek = await vault.unlockWithPassword(password);
      try {
        await action(vault, dek);
      } finally {
        zeroBytes(dek);
      }
    } on WrongPasswordException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.incorrectPassword)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reveal() => _withReauth((vault, dek) async {
    final key = await vault.revealRecoveryKey(dek);
    if (mounted) {
      setState(() => _recoveryKey = key);
    } else {
      key.destroy();
    }
  });

  Future<void> _regenerate() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.recoveryKeyRegenerate),
        content: Text(l10n.recoveryKeyRegenerateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.continueAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _withReauth((vault, dek) async {
      final rotation = await vault.prepareRecoveryKeyRotation(dek);
      if (mounted) {
        setState(() {
          _recoveryKey?.destroy();
          _recoveryKey = null;
          _rotation = rotation;
          _rotationSaved = false;
        });
      }
    });
  }

  Future<void> _commitRotation() async {
    final rotation = _rotation;
    if (rotation == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      await ref.read(keyVaultProvider).save(rotation.record);
      rotation.recoveryKey.destroy();
      setState(() => _rotation = null);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.recoveryKeyRegenerated)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorOccurred)));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rotation = _rotation;
    final shown = _recoveryKey;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryKey)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.key, size: 64, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              l10n.recoveryKeyScreenExplanation,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (rotation != null) ...[
              Text(
                l10n.recoveryKeyHeading,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.recoveryKeyExplanation),
              const SizedBox(height: 16),
              RecoveryKeyView(formattedKey: rotation.recoveryKey.format()),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _rotationSaved,
                onChanged: (value) =>
                    setState(() => _rotationSaved = value ?? false),
                title: Text(l10n.recoveryKeyConfirmSaved),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              ElevatedButton(
                onPressed: _isLoading || !_rotationSaved
                    ? null
                    : _commitRotation,
                child: Text(l10n.save),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        rotation.recoveryKey.destroy();
                        _rotation = null;
                      }),
                child: Text(l10n.cancel),
              ),
            ] else ...[
              if (shown != null) ...[
                RecoveryKeyView(formattedKey: shown.format()),
                const SizedBox(height: 24),
              ] else
                ElevatedButton(
                  onPressed: _isLoading ? null : _reveal,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.revealRecoveryKey),
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : _regenerate,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(l10n.recoveryKeyRegenerate),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
