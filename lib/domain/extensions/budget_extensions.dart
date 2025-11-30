import 'package:ledger_zero/domain/entities/budget.dart';

/// Extension methods for [Budget] entity.
extension BudgetExtensions on Budget {
  /// Returns true if the category is overspent (negative available amount).
  bool get isOverspent => available < 0;

  /// Returns true if money has been budgeted to this category.
  bool get isFunded => budgeted > 0;

  /// Returns true if there is money available to spend.
  bool get hasAvailableFunds => available > 0;
}
