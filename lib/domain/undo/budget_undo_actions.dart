import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

class BudgetChangeAction implements ReversibleAction {
  final BudgetingService _budgetingService;
  final String categoryId;
  final DateTime month;
  final int oldAmount;
  final int newAmount;

  BudgetChangeAction({
    required this._budgetingService,
    required this.categoryId,
    required this.month,
    required this.oldAmount,
    required this.newAmount,
  });

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

/// Moving [amount] (minor units) of budgeted money from one category to
/// another in [month]. Undo moves it back and redo moves it again; each
/// direction is one [BudgetingService.moveMoney] call, so both categories
/// change in the same unit of work (never only one of them).
class MoveMoneyAction implements ReversibleAction {
  final BudgetingService _budgetingService;
  final String fromCategoryId;
  final String toCategoryId;
  final int amount;
  final DateTime month;

  MoveMoneyAction({
    required this._budgetingService,
    required this.fromCategoryId,
    required this.toCategoryId,
    required this.amount,
    required this.month,
  });

  @override
  Future<void> undo() =>
      _budgetingService.moveMoney(toCategoryId, fromCategoryId, amount, month);

  @override
  Future<void> redo() =>
      _budgetingService.moveMoney(fromCategoryId, toCategoryId, amount, month);
}

/// A month operation (copy from the month before, apply a template, reset)
/// as one undoable step: undo writes the amounts the changed categories had
/// before, redo the amounts after, each in one unit of work
/// ([BudgetingService.setCategoryBudgetedAmounts]). A category deleted in
/// the meantime is skipped, the rest is still restored.
class BudgetMonthChangeAction implements ReversibleAction {
  final BudgetingService _budgetingService;
  final BudgetMonthChange change;

  BudgetMonthChangeAction({
    required this._budgetingService,
    required this.change,
  });

  @override
  Future<void> undo() =>
      _budgetingService.setCategoryBudgetedAmounts(change.before, change.month);

  @override
  Future<void> redo() =>
      _budgetingService.setCategoryBudgetedAmounts(change.after, change.month);
}
