import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/undo/transaction_undo_actions.dart';

/// Why a transaction write was rejected.
enum TransactionValidationError {
  zeroAmount,
  missingTransferAccount,
  sameTransferAccount,
  splitTransfer,
  splitWithoutLines,
  splitLineZero,
  splitSumMismatch,
  notFound,

  /// The transaction (or its transfer counterpart) is in the partner's
  /// personal account.
  partnerAccount,
}

/// Exception thrown when transaction validation fails.
class ValidationException implements Exception {
  final String message;
  final TransactionValidationError? code;

  ValidationException(this.message, [this.code]);

  @override
  String toString() => 'ValidationException: $message';
}

/// Thrown when a write would change or delete a reconciled transaction and
/// the caller has not confirmed it (`allowReconciledChange: true`).
class ReconciledTransactionException implements Exception {
  ReconciledTransactionException(this.ids);

  /// Ids of the reconciled rows that would change.
  final List<String> ids;

  @override
  String toString() => 'ReconciledTransactionException(${ids.join(', ')})';
}

/// One line of a split, as entered in the form.
class SplitLineInput {
  const SplitLineInput({
    this.id,
    required this.amount,
    this.categoryId,
    this.memo,
  });

  /// Id of the existing child row this line edits; `null` for a new line.
  final String? id;

  /// Signed amount in minor units (same sign convention as the parent).
  final int amount;
  final String? categoryId;
  final String? memo;
}

/// Everything the transaction form (or quick-add) submits.
///
/// [amount] is the signed amount of the row in [accountId]. For a transfer
/// it is the amount of this leg (negative = money leaves [accountId]); the
/// counterpart in [transferAccountId] gets `-amount`.
class TransactionInput {
  const TransactionInput({
    this.id,
    required this.accountId,
    required this.date,
    required this.amount,
    this.payeeId,
    this.newPayeeName,
    this.categoryId,
    this.memo,
    this.cleared = TransactionClearStatus.uncleared,
    this.approved = true,
    this.transferAccountId,
    this.splits = const [],
  });

  /// Id of the row being edited; `null` creates a new transaction.
  final String? id;
  final String accountId;

  /// Calendar day (stored as UTC midnight).
  final DateTime date;
  final int amount;

  /// Existing payee. When `null` and [newPayeeName] is set, the payee with
  /// that name is used (case-insensitive) or created.
  final String? payeeId;
  final String? newPayeeName;
  final String? categoryId;
  final String? memo;
  final TransactionClearStatus cleared;
  final bool approved;

  /// Destination account; set for a transfer.
  final String? transferAccountId;

  /// Split lines; non-empty for a split transaction.
  final List<SplitLineInput> splits;

  bool get isTransfer => transferAccountId != null;
  bool get isSplit => splits.isNotEmpty;
}

/// Result of [TransactionService.save].
class TransactionSaveResult {
  const TransactionSaveResult(this.id, this.action);

  /// Id of the saved row (the edited or new primary row).
  final String id;

  /// The recorded undo action.
  final TransactionChangeSetAction action;
}

/// What deleting a set of rows involves (for the confirmation dialog).
class DeletionPreview {
  const DeletionPreview({
    required this.rowCount,
    required this.includesTransfer,
    required this.includesSplit,
    required this.includesReconciled,
  });

  /// Rows that will be deleted (both legs, all children included).
  final int rowCount;

  /// A transfer is involved: its other leg is deleted too.
  final bool includesTransfer;

  /// A split is involved: the whole split is deleted (also when only one
  /// of its lines was selected).
  final bool includesSplit;

  /// At least one reconciled row would be deleted.
  final bool includesReconciled;
}

/// Result of [TransactionService.reconcile].
class ReconcileResult {
  const ReconcileResult({
    required this.reconciledCount,
    required this.difference,
    this.adjustmentId,
    required this.action,
  });

  /// Number of cleared transactions that were marked reconciled.
  final int reconciledCount;

  /// Statement balance minus cleared balance before the adjustment.
  final int difference;

  /// Id of the adjustment transaction, if one was needed.
  final String? adjustmentId;
  final TransactionChangeSetAction action;
}
