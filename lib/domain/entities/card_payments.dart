import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/domain/entities/account.dart';

/// Credit-card payment categories (YNAB style, see docs/BUDGETING_RULES.md,
/// "Credit cards").
///
/// Every on-budget, shared credit-card account has one payment category in
/// the group "Credit Card Payments". Its id is derived from the account id
/// ([DeterministicId.cardPayment]), so no column marks it: a category is a
/// payment category exactly when its id is the payment id of an account.
/// Its name follows the account's name, it holds the money set aside to pay
/// the card, and ordinary transactions cannot be categorised into it.
abstract final class CardPayments {
  /// English name of the group (its id is [groupId]; the display name is
  /// localised when the group is created).
  static const String groupEnglishName = 'Credit Card Payments';

  /// Id of the "Credit Card Payments" group.
  static String get groupId => DeterministicId.cardPaymentGroup;

  /// Id of the payment category of account [accountId].
  static String categoryId(String accountId) =>
      DeterministicId.cardPayment(accountId);

  /// Whether [account] is a budget credit card: credit type, on budget and
  /// shared (a personal account is always off budget). Only these have
  /// spending moved into a payment category; an off-budget card is a
  /// tracking account like any other.
  static bool isBudgetCard(Account account) =>
      account.type == AccountType.credit &&
      account.onBudget &&
      account.owner == AccountOwner.shared;

  /// Whether the payment category of [account] is shown and protected
  /// (cannot be deleted or moved): the card is a budget card and open. A
  /// closed card, one taken off the budget or one that is no longer a
  /// credit card keeps its (hidden) payment category.
  static bool isActive(Account account) =>
      isBudgetCard(account) && !account.isClosed;

  /// Payment category id -> account, for every account in [accounts] (the
  /// row exists for the accounts that are or were budget cards).
  static Map<String, Account> byCategoryId(Iterable<Account> accounts) => {
    for (final a in accounts) categoryId(a.id): a,
  };

  /// The ids of the payment categories of [accounts] that may hold money or
  /// be assigned to: every account's payment id (inactive ones too, so a
  /// hidden payment category is still recognised).
  static Set<String> categoryIds(Iterable<Account> accounts) => {
    for (final a in accounts) categoryId(a.id),
  };
}
