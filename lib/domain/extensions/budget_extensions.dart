import 'package:ledger_zero/domain/entities/budget.dart';

/// Extension methods for [Budget] entity.
///
/// Available and activity are not stored on [Budget]; they are computed by
/// `BudgetingService`.
extension BudgetExtensions on Budget {
  /// Returns true if money has been budgeted to this category.
  bool get isFunded => budgeted > 0;
}
