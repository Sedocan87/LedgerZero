/// Represents a group of categories in the LedgerZero application.
///
/// Category groups are used to organize categories into logical collections (e.g., "Monthly Bills", "Everyday Expenses").
class CategoryGroup {
  /// The unique identifier of the category group.
  final String id;

  /// The name of the category group.
  final String name;

  /// The sort order of the category group.
  final int? sortOrder;

  /// The date and time when the category group was created.
  final DateTime? createdAt;

  /// Creates a new [CategoryGroup] instance.
  const CategoryGroup({
    required this.id,
    required this.name,
    this.sortOrder,
    this.createdAt,
  });

  /// Creates a [CategoryGroup] from a JSON object.
  factory CategoryGroup.fromJson(Map<String, dynamic> json) {
    return CategoryGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Converts the [CategoryGroup] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
