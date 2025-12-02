import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

class BudgetChangeAction implements ReversibleAction {
  final BudgetingService _budgetingService;
  final String categoryId;
  final DateTime month;
  final double oldAmount;
  final double newAmount;

  BudgetChangeAction({
    required BudgetingService budgetingService,
    required this.categoryId,
    required this.month,
    required this.oldAmount,
    required this.newAmount,
  }) : _budgetingService = budgetingService;

  @override
  Future<void> undo() async {
    await _budgetingService.setCategoryBudgetedAmount(
      categoryId,
      oldAmount,
      month,
    );
  }

  @override
  Future<void> redo() async {
    await _budgetingService.setCategoryBudgetedAmount(
      categoryId,
      newAmount,
      month,
    );
  }
}
