/// English names of the default category groups and their categories
/// (decision D7: their ids are derived from these names with
/// `DeterministicId.defaultGroup` / `DeterministicId.defaultCategory`, so
/// every device creates identical rows; only the display name is
/// localised).
abstract final class DefaultCategories {
  /// Money set aside: a cash reserve kept in a budget account (budgeted
  /// once, it rolls over and stays out of To Be Budgeted) and money to
  /// invest. Seeded into new databases since schema v19; existing budgets
  /// are offered it once on the budget screen. Investment income (interest,
  /// dividends) is not a category: it is uncategorised income and flows
  /// into To Be Budgeted.
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
    savingsGroup: [
      'Cash Reserve',
      'Stocks & ETFs',
      'Crypto',
      'Bonds',
      'Retirement',
    ],
  };
}
