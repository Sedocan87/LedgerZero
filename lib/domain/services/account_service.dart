import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/budget_currency.dart';
import 'package:ledger_zero/domain/services/rule_reference_cleanup.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

/// Account lifecycle operations that touch other tables.
class AccountService {
  AccountService({
    required this._accountRepository,
    required this._maintenance,
    required this._ruleRepository,
    required this._unitOfWork,
    UndoService? undoService,
    BudgetingService? budgeting,
    CategoryRepository? categoryRepository,
  }) : // A named parameter cannot be a private initializing formal.
       // ignore: prefer_initializing_formals
       _undoService = undoService,
       // ignore: prefer_initializing_formals
       _budgeting = budgeting,
       // ignore: prefer_initializing_formals
       _categoryRepository = categoryRepository;

  /// Releases a closed card's payment category to To Be Budgeted; without
  /// it nothing is released.
  final BudgetingService? _budgeting;

  /// Deletes a deleted card's payment category; without it the category
  /// stays (hidden).
  final CategoryRepository? _categoryRepository;

  final AccountRepository _accountRepository;
  final ReferenceMaintenanceRepository _maintenance;
  final RuleRepository _ruleRepository;
  final UnitOfWork _unitOfWork;

  /// Cleared after a delete: recorded transaction snapshots may reference
  /// the deleted entity, and undoing them would fail on a foreign key.
  final UndoService? _undoService;

  /// Closes (or reopens) an account. Closing keeps all history; it is the
  /// recommended alternative to deleting. [currency] relabels the account
  /// in the same write (reopening a budget account into a budget that has
  /// another currency now; amounts are not converted).
  ///
  /// Closing a budget credit card hides its payment category and releases
  /// what it holds to To Be Budgeted
  /// ([BudgetingService.releasePaymentCategory], in [month], default the
  /// current one), in one unit of work; reopening shows the category again.
  /// Returns the amount released.
  Future<int> setClosed(
    String id,
    bool closed, {
    String? currency,
    DateTime? month,
  }) async {
    final account = await _accountRepository.getAccountById(id);
    if (account == null || account.isClosed == closed) {
      return 0;
    }
    final updated = account.copyWith(isClosed: closed, currency: currency);
    return _unitOfWork.run(() async {
      await _accountRepository.updateAccount(updated);
      final budgeting = _budgeting;
      if (budgeting == null ||
          !CardPayments.isActive(account) ||
          CardPayments.isActive(updated)) {
        return 0;
      }
      return budgeting.releasePaymentCategory(
        id,
        month ?? CalendarDate.startOfMonthUtc(CalendarDate.today()),
      );
    });
  }

  /// Relabels every open account in the budget that is not in [currency]
  /// to [currency], in one unit of work: all of them or none. Amounts are
  /// NOT converted (100 EUR becomes 100 CHF); this corrects a currency
  /// picked by mistake. Accounts outside the budget (personal ones too) and
  /// closed accounts keep theirs. Each account is an ordinary account
  /// edit, so it syncs to the partner's phone. Not undoable: account edits
  /// are not on the undo stack, and the same action relabels back.
  ///
  /// Returns the number of accounts relabelled.
  Future<int> relabelBudgetCurrency(String currency) {
    return _unitOfWork.run(() async {
      var count = 0;
      for (final account in await _accountRepository.getAllAccounts()) {
        if (!decidesBudgetCurrency(account) ||
            account.isPartners ||
            account.currency == currency) {
          continue;
        }
        await _accountRepository.updateAccount(
          account.copyWith(currency: currency),
        );
        count++;
      }
      return count;
    });
  }

  /// Permanently deletes account [id] in one unit of work:
  ///
  /// * transfers between this account and others: the leg in the other
  ///   account stays but becomes a normal uncategorised transaction (it
  ///   then counts towards To Be Budgeted);
  /// * all of the account's transactions (also soft-deleted ones) and its
  ///   scheduled transactions are deleted;
  /// * payee default-account references are cleared and rule actions that
  ///   move transactions into the account are removed.
  ///
  /// Returns the number of transfer legs in other accounts that were
  /// converted into normal transactions.
  Future<int> deleteAccount(String id) {
    return _unitOfWork
        .run(() async {
          final converted = await _maintenance.detachTransfersInto(id);
          await _maintenance.deleteTransactionsOfAccount(id);
          await _maintenance.deleteScheduledTransactionsOfAccount(id);
          await _maintenance.clearPayeeDefaultAccount(id);
          await replaceRuleActionReferences(
            _ruleRepository,
            type: RuleActionType.setAccount,
            fromId: id,
            toId: null,
          );
          await _deletePaymentCategory(id);
          await _accountRepository.deleteAccount(id);
          return converted;
        })
        .whenComplete(() => _undoService?.clear());
  }

  /// The payment category of a deleted card goes with it: its budgets are
  /// deleted (the money returns to To Be Budgeted, like deleting any
  /// category without a replacement); the card's spending that filled it
  /// is deleted with the account.
  Future<void> _deletePaymentCategory(String accountId) async {
    final categories = _categoryRepository;
    final categoryId = CardPayments.categoryId(accountId);
    if (categories == null ||
        await categories.getCategoryById(categoryId) == null) {
      return;
    }
    await _maintenance.moveBudgets(categoryId, null);
    await _maintenance.reassignCategoryReferences(categoryId, null);
    await replaceRuleActionReferences(
      _ruleRepository,
      type: RuleActionType.setCategory,
      fromId: categoryId,
      toId: null,
    );
    await categories.deleteCategory(categoryId);
  }
}
