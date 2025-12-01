/// Defines the type of budget goal for a category.
enum GoalType {
  /// A target balance to reach, no specific date.
  targetBalance,

  /// A target balance to reach by a specific date.
  targetBalanceByDate,

  /// A specific amount to budget every month.
  monthlyFunding;

  /// Converts the enum to a string for database storage.
  String toName() => name;

  /// Creates a [GoalType] from a string name.
  static GoalType? fromName(String? name) {
    if (name == null) {
      return null;
    }
    try {
      return GoalType.values.byName(name);
    } catch (_) {
      return null;
    }
  }
}
