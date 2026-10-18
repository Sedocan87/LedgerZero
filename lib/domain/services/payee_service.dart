import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/rule_reference_cleanup.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

/// Payee delete and merge, each in one unit of work.
class PayeeService {
  PayeeService({
    required this._payeeRepository,
    required this._maintenance,
    required this._ruleRepository,
    required this._unitOfWork,
    UndoService? undoService,
  }) : // A named parameter cannot be a private initializing formal.
       // ignore: prefer_initializing_formals
       _undoService = undoService;

  final PayeeRepository _payeeRepository;
  final ReferenceMaintenanceRepository _maintenance;
  final RuleRepository _ruleRepository;
  final UnitOfWork _unitOfWork;

  /// Cleared after a delete: recorded transaction snapshots may reference
  /// the deleted entity, and undoing them would fail on a foreign key.
  final UndoService? _undoService;

  /// Deletes payee [id]: every reference (all transactions including
  /// soft-deleted ones, scheduled transactions, parsing rules) is cleared
  /// and rule actions setting it are removed.
  Future<void> deletePayee(String id) => _replace(id, null);

  /// Merges payee [sourceId] into [targetId] and deletes the source.
  Future<void> mergePayees(String sourceId, String targetId) async {
    if (sourceId == targetId) {
      return;
    }
    final source = await _payeeRepository.getPayeeById(sourceId);
    if (source == null) {
      return;
    }
    await _replace(sourceId, targetId);
  }

  Future<void> _replace(String fromId, String? toId) {
    return _unitOfWork
        .run(() async {
          await _maintenance.reassignPayeeReferences(fromId, toId);
          await replaceRuleActionReferences(
            _ruleRepository,
            type: RuleActionType.setPayee,
            fromId: fromId,
            toId: toId,
          );
          await _payeeRepository.deletePayee(fromId);
        })
        .whenComplete(() => _undoService?.clear());
  }
}
