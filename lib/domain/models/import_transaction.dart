class ImportTransaction {
  final DateTime date;
  final double amount;
  final String? payeeName;
  final String? memo;
  final String? originalDescription;

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
    this.categoryId,
    this.accountId,
    this.isSelected = true,
    this.isDuplicate = false,
  });
}
