import 'package:flutter/material.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

/// Asks before changing a reconciled transaction. Returns `true` to go on.
Future<bool> confirmReconciledChange(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.txReconciledChangeTitle),
      content: Text(l10n.txReconciledChangeMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.txChangeAnyway),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Delete confirmation for [selectedCount] selected rows, explaining what
/// [preview] says will be deleted with them. Returns `true` to delete.
Future<bool> confirmTransactionDeletion(
  BuildContext context, {
  required int selectedCount,
  required DeletionPreview preview,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final notes = [
    if (preview.includesTransfer) l10n.txDeleteTransferNote,
    if (preview.includesSplit) l10n.txDeleteSplitNote,
    if (preview.includesReconciled) l10n.txReconciledDeleteMessage,
    l10n.txDeleteMessage,
  ];
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        selectedCount == 1
            ? l10n.txDeleteTitle
            : l10n.txDeleteManyTitle(selectedCount),
      ),
      content: Text(notes.join('\n\n')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// User-facing text for a [ValidationException] from the transaction
/// service.
String transactionValidationMessage(
  AppLocalizations l10n,
  ValidationException e,
) {
  return switch (e.code) {
    TransactionValidationError.zeroAmount => l10n.invalidAmount,
    TransactionValidationError.missingTransferAccount => l10n.selectAccount,
    TransactionValidationError.sameTransferAccount =>
      l10n.txTransferSameAccount,
    TransactionValidationError.splitTransfer => l10n.txTransferNoSplit,
    TransactionValidationError.splitWithoutLines => l10n.txSplitSumMismatch,
    TransactionValidationError.splitLineZero => l10n.txSplitLineZero,
    TransactionValidationError.splitSumMismatch => l10n.txSplitSumMismatch,
    TransactionValidationError.notFound || null => l10n.txSaveFailed,
  };
}
