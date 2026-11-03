/// The one definition of "spent" used by the home dashboard and every
/// spending report (spending by category, category breakdown, spending
/// trends, income vs expense, top payees). See docs/BUDGETING_RULES.md,
/// "Income and spending figures".
///
/// Spending rows are the non-deleted rows of on-budget accounts that are
/// not split parents (a split counts through its lines) and not transfer
/// legs (moving money between accounts, also to or from an off-budget
/// account, is never spending), and that either carry a category (any
/// sign: a refund nets against its own category) or are an uncategorised
/// outflow (spending nobody budgeted; an uncategorised inflow is income).
///
/// Netting happens within one category and one calendar month, and the
/// result is clamped at zero: a refund larger than the month's spending in
/// its category is no spending, and never offsets another category or
/// another month. A period's figure is the sum of its months.
library;

/// Net amount (signed minor units) of the spending rows of one calendar
/// month (`yyyy-MM`), one category (`null`: uncategorised outflows) and
/// one payee (`null`: no payee).
class SpendingRow {
  final String month;
  final String? categoryId;
  final String? payeeId;
  final int amount;

  const SpendingRow({
    required this.month,
    required this.categoryId,
    required this.payeeId,
    required this.amount,
  });
}

/// What was spent (positive minor units) given a net amount: the net
/// outflow, or 0 when refunds outweigh spending.
int spentOf(int netAmount) => netAmount < 0 ? -netAmount : 0;

/// Spending figures computed from [SpendingRow]s (see the library comment
/// for the rule).
class Spending {
  /// month -> category (`null`: uncategorised) -> net amount.
  final Map<String, Map<String?, int>> _byMonthCategory = {};

  /// month -> payee (`null`: no payee) -> net amount.
  final Map<String, Map<String?, int>> _byMonthPayee = {};

  /// Spending of [rows]. With a non-empty [categoryFilter] only the rows of
  /// those categories count (uncategorised outflows then do not).
  Spending(
    Iterable<SpendingRow> rows, {
    Set<String> categoryFilter = const {},
  }) {
    for (final row in rows) {
      if (categoryFilter.isNotEmpty &&
          (row.categoryId == null ||
              !categoryFilter.contains(row.categoryId))) {
        continue;
      }
      final byCategory = _byMonthCategory.putIfAbsent(row.month, () => {});
      byCategory[row.categoryId] =
          (byCategory[row.categoryId] ?? 0) + row.amount;
      final byPayee = _byMonthPayee.putIfAbsent(row.month, () => {});
      byPayee[row.payeeId] = (byPayee[row.payeeId] ?? 0) + row.amount;
    }
  }

  /// Category (`null`: uncategorised) -> spent over all months (only
  /// categories that spent something).
  Map<String?, int> get byCategory {
    final result = <String?, int>{};
    for (final month in _byMonthCategory.values) {
      for (final entry in month.entries) {
        final spent = spentOf(entry.value);
        if (spent > 0) {
          result[entry.key] = (result[entry.key] ?? 0) + spent;
        }
      }
    }
    return result;
  }

  /// Month (`yyyy-MM`) -> spent in it (only months that spent something).
  Map<String, int> get byMonth {
    final result = <String, int>{};
    for (final entry in _byMonthCategory.entries) {
      final spent = entry.value.values.fold<int>(
        0,
        (sum, net) => sum + spentOf(net),
      );
      if (spent > 0) {
        result[entry.key] = spent;
      }
    }
    return result;
  }

  /// Total spent (positive minor units).
  int get total => byMonth.values.fold<int>(0, (sum, v) => sum + v);

  /// Payee (`null`: no payee) -> spent with it over all months: its net
  /// per month, clamped at zero (only payees that were paid something).
  Map<String?, int> get byPayee {
    final result = <String?, int>{};
    for (final month in _byMonthPayee.values) {
      for (final entry in month.entries) {
        final spent = spentOf(entry.value);
        if (spent > 0) {
          result[entry.key] = (result[entry.key] ?? 0) + spent;
        }
      }
    }
    return result;
  }
}
