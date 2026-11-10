import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:uuid/uuid.dart';

/// Deterministic (name-based, UUIDv5) identifiers (decision D7).
///
/// Rows that represent a natural key get an id derived from that key, so two
/// devices (or a retried operation) that create "the same" row produce the
/// same id and sync/insert-or-ignore can deduplicate them:
///
/// * budget row: `budget:<categoryId>:<yyyy-MM>`
/// * seeded default group: `default-group:<name>`
/// * seeded default category: `default-category:<group>/<name>`
/// * scheduled occurrence: `scheduled:<scheduledId>:<yyyy-MM-dd>`
/// * payment category of a credit card: `card-payment:<accountId>`
/// * the "Credit Card Payments" group: `card-payment-group`
abstract final class DeterministicId {
  /// Fixed LedgerZero namespace for all name-based ids. Never change it:
  /// existing ids are derived from it.
  static const String namespace = '6f1c7a52-3d0e-5b8a-9c41-2e7d8b0f4a13';

  static const Uuid _uuid = Uuid();

  /// UUIDv5 of [name] in the app [namespace].
  static String of(String name) => _uuid.v5(namespace, name);

  /// Id of the budget row of [categoryId] in [month] (any day of the month).
  static String budget(String categoryId, DateTime month) =>
      budgetForKey(categoryId, CalendarDate.monthKey(month));

  /// Id of the budget row of [categoryId] for a `yyyy-MM` [monthKey].
  static String budgetForKey(String categoryId, String monthKey) =>
      of('budget:$categoryId:$monthKey');

  /// Id of a seeded default category group.
  static String defaultGroup(String name) => of('default-group:$name');

  /// Id of a seeded default category.
  static String defaultCategory(String group, String name) =>
      of('default-category:$group/$name');

  /// Id of the payment category of the credit-card account [accountId]
  /// (see `CardPayments`): derived from the account, so every device that
  /// has the account creates the same category row.
  static String cardPayment(String accountId) => of('card-payment:$accountId');

  /// Id of the "Credit Card Payments" group that holds the payment
  /// categories.
  static final String cardPaymentGroup = of('card-payment-group');

  /// Id of the transaction materialised from schedule [scheduledId] for the
  /// calendar day [date].
  static String scheduledOccurrence(String scheduledId, DateTime date) {
    final d = CalendarDate.normalize(date);
    final day =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return of('scheduled:$scheduledId:$day');
  }
}
