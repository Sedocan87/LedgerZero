/// Represents a budget allocation for a category in a specific month.
///
/// This entity tracks how much money is budgeted, spent, and available for a category.
class Budget {
  /// The unique identifier of the budget.
  final String id;

  /// The unique identifier of the category this budget applies to.
  final String? categoryId;

  /// The month this budget is for, in "YYYY-MM" format.
  final String month;

  /// The amount of money allocated to this category for the month.
  final double budgeted;

  /// The amount of money spent (activity) in this category for the month.
  final double activity;

  /// The amount of money available in this category.
  ///
  /// Calculated as: Budgeted - Activity + Carry-over from previous month.
  final double available;

  /// The date and time when the budget was created.
  final DateTime? createdAt;

  /// The date and time when the budget was last updated.
  final DateTime? updatedAt;

  /// Creates a new [Budget] instance.
  const Budget({
    required this.id,
    this.categoryId,
    required this.month,
    this.budgeted = 0.0,
    this.activity = 0.0,
    this.available = 0.0,
    this.createdAt,
    this.updatedAt,
  });
}
