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

  /// Creates a copy of this [CategoryGroup] but with the given fields replaced with the new values.
  CategoryGroup copyWith({
    String? id,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CategoryGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is CategoryGroup &&
        other.id == id &&
        other.name == name &&
        other.sortOrder == sortOrder &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      sortOrder,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'CategoryGroup(id: $id, name: $name, sortOrder: $sortOrder, createdAt: $createdAt)';
  }

  /// Validates the [CategoryGroup] entity.
  ///
  /// Returns a list of error messages. If the list is empty, the entity is valid.
  List<String> validate() {
    final errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Category group name cannot be empty');
    }
    return errors;
  }
}
