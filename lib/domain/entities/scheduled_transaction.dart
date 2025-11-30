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
    this.nextDate,
    this.endDate,
    this.autoApprove = false,
    this.createdAt,
  });
}
