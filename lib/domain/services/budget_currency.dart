import 'package:ledger_zero/domain/entities/account.dart';

/// Whether [account] decides the budget currency: it is in the budget and
/// open. A closed account keeps its currency (closing the accounts and
/// opening new ones is how a budget really moves to another currency).
bool decidesBudgetCurrency(Account account) =>
    account.onBudget && !account.isClosed;

/// The budget currency (docs/BUDGETING_RULES.md, "Budget currency").
///
/// While no open account is in the budget it is the stored setting
/// (Settings > Currency). Once one is, it is the currency of the accounts
/// in the budget: To Be Budgeted adds them up, and amounts in different
/// currencies are never converted.
class BudgetCurrency {
  const BudgetCurrency({
    required this.currency,
    this.onBudgetCurrencies = const [],
  });

  /// Derives the budget currency from [accounts]; [setting] is the stored
  /// one. Accounts in the budget that disagree (data from before the rule,
  /// an import, a sync race) keep [setting] when it is one of theirs, else
  /// the currency most of them use.
  factory BudgetCurrency.of(
    Iterable<Account> accounts, {
    required String setting,
  }) {
    final counts = <String, int>{};
    for (final a in accounts) {
      if (decidesBudgetCurrency(a)) {
        counts[a.currency] = (counts[a.currency] ?? 0) + 1;
      }
    }
    final currencies = counts.keys.toList()..sort();
    if (currencies.isEmpty || counts.containsKey(setting)) {
      return BudgetCurrency(currency: setting, onBudgetCurrencies: currencies);
    }
    var best = currencies.first;
    for (final c in currencies) {
      if (counts[c]! > counts[best]!) {
        best = c;
      }
    }
    return BudgetCurrency(currency: best, onBudgetCurrencies: currencies);
  }

  /// The budget currency.
  final String currency;

  /// The currencies of the open accounts in the budget (sorted, distinct).
  /// Empty while there is none.
  final List<String> onBudgetCurrencies;

  /// Set by the accounts in the budget, not by Settings.
  bool get isFixed => onBudgetCurrencies.isNotEmpty;

  /// The accounts in the budget use more than one currency.
  bool get isMixed => onBudgetCurrencies.length > 1;

  /// The open accounts in the budget among [accounts] that are not in the
  /// budget currency.
  List<Account> oddAccounts(Iterable<Account> accounts) => [
    for (final a in accounts)
      if (decidesBudgetCurrency(a) && a.currency != currency) a,
  ];

  @override
  bool operator ==(Object other) =>
      other is BudgetCurrency &&
      other.currency == currency &&
      other.onBudgetCurrencies.length == onBudgetCurrencies.length &&
      other.onBudgetCurrencies.indexed.every(
        (e) => onBudgetCurrencies[e.$1] == e.$2,
      );

  @override
  int get hashCode => Object.hash(currency, Object.hashAll(onBudgetCurrencies));

  @override
  String toString() => 'BudgetCurrency($currency, $onBudgetCurrencies)';
}
