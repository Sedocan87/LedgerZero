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

  /// The date and time when the category was created.
  final DateTime? createdAt;

  /// Creates a new [Category] instance.
  const Category({
    required this.id,
    required this.name,
    this.categoryGroupId,
    this.isHidden = false,
    this.sortOrder,
    this.createdAt,
  });
}
