import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/services/import/import_undo_service.dart';

/// "Undo last import": says what would be deleted and what is kept, asks,
/// then deletes the unchanged transactions of the last CSV import (see
/// [ImportUndoService]). Returns whether the import was undone (or its
/// record dropped because nothing was left to undo).
Future<bool> confirmAndUndoLastImport(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(importUndoServiceProvider);
  final formatter = ref.read(appFormatterProvider);
  try {
    final preview = await service.preview();
    if (preview == null || !context.mounted) {
      return false;
    }
    final count = preview.removable.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importUndoLast),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count == 0
                  ? l10n.importUndoNothing
                  : l10n.importUndoConfirm(
                      count,
                      formatter.formatDate(preview.importedAt.toLocal()),
                    ),
            ),
            if (count > 0 && preview.changed > 0) ...[
              const SizedBox(height: 12),
              Text(
                l10n.importUndoKept(preview.changed),
                key: const Key('import_undo_kept'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          if (count > 0)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(count == 0 ? l10n.ok : l10n.importUndoAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return false;
    }
    final done = await service.undo();
    if (done != null && done.removable.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(undoneMessage(l10n, done))),
      );
    }
    return true;
  } catch (e, st) {
    Logger.error('Undoing the last import failed', e, st);
    messenger.showSnackBar(SnackBar(content: Text(l10n.importUndoFailed)));
    return false;
  }
}

/// The snackbar text after an undo: how many transactions were deleted
/// and, when some were changed since the import, how many were kept.
String undoneMessage(AppLocalizations l10n, ImportUndoPreview done) => [
  l10n.importUndoDone(done.removable.length),
  if (done.changed > 0) l10n.importUndoKept(done.changed),
].join('\n');
