import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Displays a recovery key for writing down. Deliberately not selectable
/// and without a copy button: the clipboard is readable by other apps and
/// may sync to other devices.
class RecoveryKeyView extends StatelessWidget {
  final String formattedKey;

  const RecoveryKeyView({super.key, required this.formattedKey});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = formattedKey.split('-');
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outline),
          ),
          child: Semantics(
            label: groups.join(' '),
            child: ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final group in groups)
                    Text(
                      group,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontFamilyFallback: ['Courier', 'Menlo'],
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.recoveryKeyNoCopyNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
