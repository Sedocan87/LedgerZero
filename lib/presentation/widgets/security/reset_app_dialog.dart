import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Confirmation for a factory reset from the lock screen: the reset button
/// is enabled only after typing the localised confirmation word.
class ResetAppDialog extends StatefulWidget {
  const ResetAppDialog({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  State<ResetAppDialog> createState() => _ResetAppDialogState();
}

class _ResetAppDialogState extends State<ResetAppDialog> {
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
