import 'package:ledger_zero/domain/entities/enums/goal_type.dart';

/// Represents a transaction category in the LedgerZero application.
///
/// Categories are used to classify transactions and can be grouped into category groups.
class Category {
  /// The unique identifier of the category.
  final String id;

  /// The name of the category.
  final String name;

  /// The unique identifier of the category group this category belongs to.
  final String? categoryGroupId;

  /// Whether the category is hidden from the budget view.
  final bool isHidden;

  /// The sort order of the category within its group.
  final int? sortOrder;

  /// The type of goal for this category.
  final GoalType? goalType;

  /// The target amount for the goal.
  final double? targetAmount;

  /// The target date for the goal.
  final DateTime? targetDate;

  /// The date and time when the category was created.
  final DateTime? createdAt;

  /// Creates a new [Category] instance.
  const Category({
    required this.id,
    required this.name,
    this.categoryGroupId,
    this.isHidden = false,
    this.sortOrder,
    this.goalType,
    this.targetAmount,
    this.targetDate,
    this.createdAt,
  });

  /// Creates a copy of this [Category] but with the given fields replaced with the new values.
  Category copyWith({
    String? id,
    String? name,
    String? categoryGroupId,
    bool? isHidden,
    int? sortOrder,
    GoalType? goalType,
    double? targetAmount,
    DateTime? targetDate,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryGroupId: categoryGroupId ?? this.categoryGroupId,
      isHidden: isHidden ?? this.isHidden,
      sortOrder: sortOrder ?? this.sortOrder,
      goalType: goalType ?? this.goalType,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Creates a [Category] from a JSON object.
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryGroupId: json['category_group_id'] as String?,
      isHidden: json['is_hidden'] as bool? ?? false,
      sortOrder: json['sort_order'] as int?,
      goalType: GoalType.fromName(json['goal_type'] as String?),
      targetAmount: (json['target_amount'] as num?)?.toDouble(),
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Converts the [Category] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_group_id': categoryGroupId,
      'is_hidden': isHidden,
      'sort_order': sortOrder,
      'goal_type': goalType?.toName(),
      'target_amount': targetAmount,
      'target_date': targetDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.categoryGroupId == categoryGroupId &&
        other.isHidden == isHidden &&
        other.sortOrder == sortOrder &&
        other.goalType == goalType &&
        other.targetAmount == targetAmount &&
        other.targetDate == targetDate &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      categoryGroupId,
      isHidden,
      sortOrder,
      goalType,
      targetAmount,
      targetDate,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'Category(id: $id, name: $name, categoryGroupId: $categoryGroupId, isHidden: $isHidden, sortOrder: $sortOrder, goalType: $goalType, targetAmount: $targetAmount, targetDate: $targetDate, createdAt: $createdAt)';
  }

  /// Validates the [Category] entity.
  ///
  /// Returns a list of error messages. If the list is empty, the entity is valid.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Category name cannot be empty');
    }
    return errors;
  }
}
