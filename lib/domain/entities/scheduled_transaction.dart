/// The frequency at which a scheduled transaction repeats.
enum RecurrenceFrequency {
  /// Repeats daily.
  daily,

  /// Repeats weekly.
  weekly,

  /// Repeats monthly.
  monthly,

  /// Repeats yearly.
  yearly,
}

/// Represents a scheduled transaction in the LedgerZero application.
///
/// A scheduled transaction is a transaction that occurs in the future, potentially repeating.
class ScheduledTransaction {
  /// The unique identifier of the scheduled transaction.
  final String id;

  /// The unique identifier of the account this scheduled transaction belongs to.
  final String? accountId;

  /// The unique identifier of the payee associated with this scheduled transaction.
  final String? payeeId;

  /// The unique identifier of the category associated with this scheduled transaction.
  final String? categoryId;

  /// The amount of the scheduled transaction.
  final double? amount;

  /// The frequency of recurrence.
  final RecurrenceFrequency? frequency;

  /// The interval of recurrence (e.g., every 2 weeks).
  final int? interval;

  /// The number of occurrences to run before stopping.
  final int? occurrenceCount;

  /// The date of the next occurrence.
  final DateTime? nextDate;

  /// The date when the schedule ends.
  final DateTime? endDate;

  /// Whether the transaction should be automatically approved when created.
  final bool autoApprove;

  /// The date and time when the scheduled transaction was created.
  final DateTime? createdAt;

  /// Creates a new [ScheduledTransaction] instance.
  const ScheduledTransaction({
    required this.id,
    this.accountId,
    this.payeeId,
    this.categoryId,
    this.amount,
    this.frequency,
    this.interval,
    this.occurrenceCount,
    this.nextDate,
    this.endDate,
    this.autoApprove = false,
    this.createdAt,
  });

  /// Creates a copy of this [ScheduledTransaction] but with the given fields replaced with the new values.
  ScheduledTransaction copyWith({
    String? id,
    String? accountId,
    String? payeeId,
    String? categoryId,
    double? amount,
    RecurrenceFrequency? frequency,
    int? interval,
    int? occurrenceCount,
    DateTime? nextDate,
    DateTime? endDate,
    bool? autoApprove,
    DateTime? createdAt,
  }) {
    return ScheduledTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      payeeId: payeeId ?? this.payeeId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      nextDate: nextDate ?? this.nextDate,
      endDate: endDate ?? this.endDate,
      autoApprove: autoApprove ?? this.autoApprove,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Creates a [ScheduledTransaction] from a JSON object.
  factory ScheduledTransaction.fromJson(Map<String, dynamic> json) {
    return ScheduledTransaction(
      id: json['id'] as String,
      accountId: json['account_id'] as String?,
      payeeId: json['payee_id'] as String?,
      categoryId: json['category_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      frequency: json['frequency'] != null
          ? RecurrenceFrequency.values.firstWhere(
              (e) => e.name == json['frequency'],
            )
          : null,
      interval: json['interval'] as int?,
      occurrenceCount: json['occurrence_count'] as int?,
      nextDate: json['next_date'] != null
          ? DateTime.parse(json['next_date'] as String)
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      autoApprove: json['auto_approve'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Converts the [ScheduledTransaction] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'payee_id': payeeId,
      'category_id': categoryId,
      'amount': amount,
      'frequency': frequency?.name,
      'interval': interval,
      'occurrence_count': occurrenceCount,
      'next_date': nextDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'auto_approve': autoApprove,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ScheduledTransaction &&
        other.id == id &&
        other.accountId == accountId &&
        other.payeeId == payeeId &&
        other.categoryId == categoryId &&
        other.amount == amount &&
        other.frequency == frequency &&
        other.interval == interval &&
        other.occurrenceCount == occurrenceCount &&
        other.nextDate == nextDate &&
        other.endDate == endDate &&
        other.autoApprove == autoApprove &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      accountId,
      payeeId,
      categoryId,
      amount,
      frequency,
      interval,
      occurrenceCount,
      nextDate,
      endDate,
      autoApprove,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'ScheduledTransaction(id: $id, accountId: $accountId, payeeId: $payeeId, categoryId: $categoryId, amount: $amount, frequency: $frequency, interval: $interval, occurrenceCount: $occurrenceCount, nextDate: $nextDate, endDate: $endDate, autoApprove: $autoApprove, createdAt: $createdAt)';
  }

  /// Validates the [ScheduledTransaction] entity.
  ///
  /// Returns a list of error messages. If the list is empty, the entity is valid.
  List<String> validate() {
    final errors = <String>[];
    if (amount != null && amount == 0.0) {
      errors.add('Scheduled transaction amount cannot be zero');
    }
    if (nextDate != null && endDate != null && endDate!.isBefore(nextDate!)) {
      errors.add('End date cannot be before next date');
    }
    if (interval != null && interval! < 1) {
      errors.add('Interval must be at least 1');
    }
    if (occurrenceCount != null && occurrenceCount! < 1) {
      errors.add('Occurrence count must be at least 1');
    }
    return errors;
  }
}
