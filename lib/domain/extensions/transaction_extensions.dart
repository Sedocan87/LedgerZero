import 'package:ledger_zero/domain/entities/transaction.dart';

/// Extension methods for [Transaction] entity.
extension TransactionExtensions on Transaction {
  /// Returns true if the transaction is an income (inflow).
  bool get isIncome => amount > 0;

  /// Returns true if the transaction is an expense (outflow).
  bool get isExpense => amount < 0;

  /// Returns true if the transaction is a transfer to another account.
  bool get isTransfer => transferAccountId != null;

  /// Returns true if the transaction is cleared.
  bool get isCleared => cleared == TransactionClearStatus.cleared;

  /// Returns true if the transaction is reconciled.
  bool get isReconciled => cleared == TransactionClearStatus.reconciled;

  /// Returns true if the transaction is uncleared.
  bool get isUncleared => cleared == TransactionClearStatus.uncleared;
}
