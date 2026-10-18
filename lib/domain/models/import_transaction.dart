import 'package:ledger_zero/domain/entities/transaction.dart';

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

  /// The cleared state the file states (`Cleared` column), or `null` when
  /// the file has none (imported rows are then cleared).
  final TransactionClearStatus? cleared;

  /// The account name of the file's Account column (an exported file
  /// lists several accounts), or `null`.
  final String? accountName;

  /// For a transfer leg: the other account's name from the file's
  /// Transfer column, or `null`.
  final String? transferAccountName;

  // These might be inferred or user-selected later
  String? categoryId;

  /// The account the row goes into when it differs from the one chosen on
  /// the review screen ("account from file").
  String? accountId;

  /// The payee name a rule would set for this row (its "set payee"
  /// action), filled by the duplicate check so that a row already imported
  /// under that name is recognised.
  String? rulePayeeName;

  // UI State
  bool isSelected;
  bool isDuplicate;

  /// An existing transaction without payee (a hand-entered transfer, for
  /// instance) has the same day and amount: shown unselected, the user
  /// decides.
  bool isPossibleDuplicate;

  ImportTransaction({
    required this.date,
    required this.amount,
    this.payeeName,
    this.memo,
    this.originalDescription,
    this.categoryName,
    this.cleared,
    this.accountName,
    this.transferAccountName,
    this.categoryId,
    this.accountId,
    this.rulePayeeName,
    this.isSelected = true,
    this.isDuplicate = false,
    this.isPossibleDuplicate = false,
  });

  /// A copy with the same values and UI state.
  ImportTransaction copy() => ImportTransaction(
    date: date,
    amount: amount,
    payeeName: payeeName,
    memo: memo,
    originalDescription: originalDescription,
    categoryName: categoryName,
    cleared: cleared,
    accountName: accountName,
    transferAccountName: transferAccountName,
    categoryId: categoryId,
    accountId: accountId,
    rulePayeeName: rulePayeeName,
    isSelected: isSelected,
    isDuplicate: isDuplicate,
    isPossibleDuplicate: isPossibleDuplicate,
  );

  /// The file named a category that does not exist: the row is imported
  /// without a category (rules or the payee default may still assign one).
  bool get hasUnmatchedCategory =>
      categoryId == null && (categoryName?.trim().isNotEmpty ?? false);
}
