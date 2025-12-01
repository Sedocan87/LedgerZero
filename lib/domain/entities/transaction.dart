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

  /// Whether the transaction has been soft-deleted.
  final bool isDeleted;

  /// The unique identifier of the destination account for transfers.
  final String? transferAccountId;

  /// The unique identifier of the counterpart transaction for transfers.
  final String? transferTransactionId;

  /// The unique identifier of the parent transaction for splits.
  final String? parentTransactionId;

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
    this.isDeleted = false,
    this.transferAccountId,
    this.transferTransactionId,
    this.parentTransactionId,
    this.createdAt,
    this.updatedAt,
  });

  /// Creates a copy of this [Transaction] but with the given fields replaced with the new values.
  Transaction copyWith({
    String? id,
    String? accountId,
    DateTime? date,
    double? amount,
    String? payeeId,
    String? categoryId,
    String? memo,
    TransactionClearStatus? cleared,
    bool? approved,
    bool? isDeleted,
    String? transferAccountId,
    String? transferTransactionId,
    String? parentTransactionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      payeeId: payeeId ?? this.payeeId,
      categoryId: categoryId ?? this.categoryId,
      memo: memo ?? this.memo,
      cleared: cleared ?? this.cleared,
      approved: approved ?? this.approved,
      isDeleted: isDeleted ?? this.isDeleted,
      transferAccountId: transferAccountId ?? this.transferAccountId,
      transferTransactionId: transferTransactionId ?? this.transferTransactionId,
      parentTransactionId: parentTransactionId ?? this.parentTransactionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates a [Transaction] from a JSON object.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      payeeId: json['payee_id'] as String?,
      categoryId: json['category_id'] as String?,
      memo: json['memo'] as String?,
      cleared: json['cleared'] != null
          ? TransactionClearStatus.values[json['cleared'] as int]
          : TransactionClearStatus.uncleared,
      approved: json['approved'] as bool? ?? true,
      isDeleted: json['is_deleted'] as bool? ?? false,
      transferAccountId: json['transfer_account_id'] as String?,
      transferTransactionId: json['transfer_transaction_id'] as String?,
      parentTransactionId: json['parent_transaction_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converts the [Transaction] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'date': date.toIso8601String(),
      'amount': amount,
      'payee_id': payeeId,
      'category_id': categoryId,
      'memo': memo,
      'cleared': cleared.index,
      'approved': approved,
      'is_deleted': isDeleted,
      'transfer_account_id': transferAccountId,
      'transfer_transaction_id': transferTransactionId,
      'parent_transaction_id': parentTransactionId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Transaction &&
        other.id == id &&
        other.accountId == accountId &&
        other.date == date &&
        other.amount == amount &&
        other.payeeId == payeeId &&
        other.categoryId == categoryId &&
        other.memo == memo &&
        other.cleared == cleared &&
        other.approved == approved &&
        other.isDeleted == isDeleted &&
        other.transferAccountId == transferAccountId &&
        other.transferTransactionId == transferTransactionId &&
        other.parentTransactionId == parentTransactionId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      accountId,
      date,
      amount,
      payeeId,
      categoryId,
      memo,
      cleared,
      approved,
      isDeleted,
      transferAccountId,
      transferTransactionId,
      parentTransactionId,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, accountId: $accountId, date: $date, amount: $amount, payeeId: $payeeId, categoryId: $categoryId, memo: $memo, cleared: $cleared, approved: $approved, isDeleted: $isDeleted, transferAccountId: $transferAccountId, transferTransactionId: $transferTransactionId, parentTransactionId: $parentTransactionId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  /// Validates the [Transaction] entity.
  ///
  /// Returns a list of error messages. If the list is empty, the entity is valid.
  List<String> validate() {
    final errors = <String>[];
    if (amount == 0.0) {
      errors.add('Transaction amount cannot be zero');
    }
    return errors;
  }
}
