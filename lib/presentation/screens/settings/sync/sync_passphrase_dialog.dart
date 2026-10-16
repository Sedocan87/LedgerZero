import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/sync/sync_controller.dart';
import 'package:ledger_zero/presentation/widgets/security/password_strength_meter.dart';
import 'package:ledger_zero/services/security/password_policy.dart';

/// Asks for the sync passphrase. With [create] the user chooses a new one
/// (strength rules of [PasswordPolicy], typed twice); otherwise the user
/// enters the passphrase set on the first device. [submit] performs the
/// setup; the dialog stays open and shows the error on failure.
class SyncPassphraseDialog extends StatefulWidget {
  final bool create;
  final Future<SyncPassphraseResult> Function(String passphrase) submit;

  const SyncPassphraseDialog({
    super.key,
    required this.create,
    required this.submit,
  });

  static Future<bool?> show(
    BuildContext context, {
    required bool create,
    required Future<SyncPassphraseResult> Function(String passphrase) submit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SyncPassphraseDialog(create: create, submit: submit),
    );
  }

  @override
  State<SyncPassphraseDialog> createState() => _SyncPassphraseDialogState();
}

class _SyncPassphraseDialogState extends State<SyncPassphraseDialog> {
  final _passphrase = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    final value = _passphrase.text;
    if (widget.create) {
      final strength = PasswordPolicy.evaluate(value);
      if (strength == PasswordStrength.tooShort) {
        setState(
          () => _error = l10n.passwordMinLength(PasswordPolicy.minLength),
        );
        return;
      }
      if (strength == PasswordStrength.common) {
        setState(() => _error = l10n.passwordTooCommon);
        return;
      }
      if (value != _confirm.text) {
        setState(() => _error = l10n.passwordsDoNotMatch);
        return;
      }
    } else if (value.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.submit(value);
    if (!mounted) {
      return;
    }
    switch (result) {
      case SyncPassphraseResult.ok:
        Navigator.of(context).pop(true);
      case SyncPassphraseResult.wrongPassphrase:
        setState(() {
          _busy = false;
          _error = l10n.syncPassphraseWrong;
        });
      case SyncPassphraseResult.folderExists:
        setState(() {
          _busy = false;
          _error = l10n.syncPassphraseFolderExists;
        });
      case SyncPassphraseResult.failed:
        setState(() {
          _busy = false;
          _error = l10n.syncPassphraseFailed;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.create
            ? l10n.syncPassphraseSetTitle
            : l10n.syncPassphraseEnterTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.create
                  ? l10n.syncPassphraseSetExplanation
                  : l10n.syncPassphraseEnterExplanation,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('syncPassphraseField'),
              controller: _passphrase,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.syncPassphraseLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (widget.create) ...[
              const SizedBox(height: 8),
              PasswordStrengthMeter(password: _passphrase.text),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('syncPassphraseConfirmField'),
                controller: _confirm,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l10n.syncPassphraseConfirmLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _busy ? null : _onSubmit,
          child: Text(
            widget.create
                ? l10n.syncPassphraseSetButton
                : l10n.syncPassphraseEnterButton,
          ),
        ),
      ],
    );
  }
}
