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

  /// Creates a [Budget] from a JSON object.
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      categoryId: json['category_id'] as String?,
      month: json['month'] as String,
      budgeted: (json['budgeted'] as num?)?.toDouble() ?? 0.0,
      activity: (json['activity'] as num?)?.toDouble() ?? 0.0,
      available: (json['available'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Converts the [Budget] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'month': month,
      'budgeted': budgeted,
      'activity': activity,
      'available': available,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Budget &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.month == month &&
        other.budgeted == budgeted &&
        other.activity == activity &&
        other.available == available &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      categoryId,
      month,
      budgeted,
      activity,
      available,
      createdAt,
      updatedAt,
    );
  }
}
