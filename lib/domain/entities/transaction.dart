/// The cleared status of a transaction.
enum TransactionClearStatus {
  /// The transaction has not yet cleared the bank.
  uncleared,

  /// The transaction has cleared the bank.
  cleared,

  /// The transaction has been reconciled with a bank statement.
  reconciled,
}

/// Represents a financial transaction in the LedgerZero application.
///
/// A transaction records a movement of money, such as an expense, income, or transfer.
class Transaction {
  /// The unique identifier of the transaction.
  final String id;

  /// The unique identifier of the account this transaction belongs to.
  final String accountId;

  /// The date of the transaction.
  final DateTime date;

  /// The amount of the transaction.
  ///
  /// Negative values indicate outflows (spending), positive values indicate inflows (income).
  final double amount;

  /// The unique identifier of the payee associated with this transaction.
  final String? payeeId;

  /// The unique identifier of the category associated with this transaction.
  final String? categoryId;

  /// A memo or note describing the transaction.
  final String? memo;

  /// The cleared status of the transaction.
  final TransactionClearStatus cleared;

  /// Whether the transaction has been approved.
  final bool approved;

  /// The unique identifier of the destination account for transfers.
  final String? transferAccountId;

  /// The unique identifier of the counterpart transaction for transfers.
  final String? transferTransactionId;

  /// The date and time when the transaction was created.
  final DateTime? createdAt;

  /// The date and time when the transaction was last updated.
  final DateTime? updatedAt;

  /// Creates a new [Transaction] instance.
  const Transaction({
    required this.id,
    required this.accountId,
    required this.date,
    required this.amount,
    this.payeeId,
    this.categoryId,
    this.memo,
    this.cleared = TransactionClearStatus.uncleared,
    this.approved = true,
    this.transferAccountId,
    this.transferTransactionId,
    this.createdAt,
    this.updatedAt,
  });
}
