class ImportTransaction {
  final DateTime date;

  /// Amount in minor units (negative = outflow).
  final int amount;
  final String? payeeName;
  final String? memo;
  final String? originalDescription;

  /// The category text of the file's Category column, as written there.
  /// [categoryId] is set when it names an existing category.
  final String? categoryName;

  // These might be inferred or user-selected later
  String? categoryId;
  String? accountId;

  // UI State
  bool isSelected;
  bool isDuplicate;

  ImportTransaction({
    required this.date,
    required this.amount,
    this.payeeName,
    this.memo,
    this.originalDescription,
    this.categoryName,
    this.categoryId,
    this.accountId,
    this.isSelected = true,
    this.isDuplicate = false,
  });

  /// The file named a category that does not exist: the row is imported
  /// without a category (rules or the payee default may still assign one).
  bool get hasUnmatchedCategory =>
      categoryId == null && (categoryName?.trim().isNotEmpty ?? false);
}
