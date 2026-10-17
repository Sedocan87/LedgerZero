/// English names of the default category groups and their categories
/// (decision D7: their ids are derived from these names with
/// `DeterministicId.defaultGroup` / `DeterministicId.defaultCategory`, so
/// every device creates identical rows; only the display name is
/// localised).
abstract final class DefaultCategories {
  /// What is moved to savings and investment accounts each month. Those
  /// accounts are kept outside the budget (net worth only), so the
  /// transfer to them leaves the budget through one of these categories.
  /// Seeded into new databases since schema v19 ("Cash Reserve" until it
  /// was replaced by "Savings"; existing budgets keep theirs); budgets
  /// without the group are offered it once on the budget screen.
  /// Investment income (interest, dividends) is not a category: it is
  /// uncategorised income and flows into To Be Budgeted (or stays in an
  /// off-budget account).
  static const savingsGroup = 'Savings & Investments';

  /// Group name -> category names, in display order.
  static const Map<String, List<String>> groups = {
    'Immediate Obligations': [
      'Rent/Mortgage',
      'Electric',
      'Water',
      'Internet',
      'Groceries',
      'Transportation',
    ],
    'True Expenses': [
      'Medical',
      'Auto Maintenance',
      'Home Maintenance',
      'Renter\'s/Home Insurance',
      'Software Subscriptions',
    ],
    'Debt Payments': ['Student Loan', 'Car Payment', 'Credit Card'],
    'Quality of Life': [
      'Vacation',
      'Fitness',
      'Education',
      'Dining Out',
      'Entertainment',
    ],
    'Just for Fun': ['Gaming', 'Music', 'Fun Money'],
    savingsGroup: ['Savings', 'Stocks & ETFs', 'Crypto', 'Bonds', 'Retirement'],
  };
}
