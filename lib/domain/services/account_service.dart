import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/rule_reference_cleanup.dart';

/// Account lifecycle operations that touch other tables.
class AccountService {
  AccountService({
    required this._accountRepository,
    required this._maintenance,
    required this._ruleRepository,
    required this._unitOfWork,
  });

  final AccountRepository _accountRepository;
  final ReferenceMaintenanceRepository _maintenance;
  final RuleRepository _ruleRepository;
  final UnitOfWork _unitOfWork;

  /// Closes (or reopens) an account. Closing keeps all history; it is the
  /// recommended alternative to deleting.
  Future<void> setClosed(String id, bool closed) async {
    final account = await _accountRepository.getAccountById(id);
    if (account != null && account.isClosed != closed) {
      await _accountRepository.updateAccount(
        account.copyWith(isClosed: closed),
      );
    }
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
    return _unitOfWork.run(() async {
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
      await _accountRepository.deleteAccount(id);
      return converted;
    });
  }
}
