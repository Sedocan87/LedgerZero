import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/rule_reference_cleanup.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

/// A payee cannot be renamed to the name of another payee: two payees with
/// one name are indistinguishable when a name is resolved (typing it,
/// imports, rules). The user is offered to merge into [existing] instead.
class PayeeNameTakenException implements Exception {
  const PayeeNameTakenException(this.existing);

  final Payee existing;

  @override
  String toString() => 'PayeeNameTakenException: ${existing.name}';
}

/// Payee rename, delete and merge, each in one unit of work.
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

  /// Renames payee [id] to [name] (trimmed). Rule conditions that compare
  /// the payee with the old name by equality follow the new name (see
  /// [renamePayeeConditions]), unless another payee still carries the old
  /// name. Changing only the
  /// case is a rename too.
  ///
  /// Throws [PayeeNameTakenException] when another payee already has that
  /// name (ignoring case) and [ArgumentError] for an empty name.
  Future<void> renamePayee(String id, String name) async {
    final newName = name.trim();
    if (newName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    await _unitOfWork.run(() async {
      final payee = await _payeeRepository.getPayeeById(id);
      if (payee == null || payee.name == newName) {
        return;
      }
      final all = await _payeeRepository.getAllPayees();
      final taken = all
          .where(
            (p) => p.id != id && p.name.toLowerCase() == newName.toLowerCase(),
          )
          .firstOrNull;
      if (taken != null) {
        throw PayeeNameTakenException(taken);
      }
      await _payeeRepository.updatePayee(payee.copyWith(name: newName));
      final oldNameStillUsed = all.any(
        (p) => p.id != id && p.name.toLowerCase() == payee.name.toLowerCase(),
      );
      if (!oldNameStillUsed) {
        await renamePayeeConditions(
          _ruleRepository,
          from: payee.name,
          to: newName,
        );
      }
    });
  }

  /// Deletes payee [id]: every reference (all transactions including
  /// soft-deleted ones, scheduled transactions, parsing rules) is cleared
  /// and rule actions setting it are removed.
  Future<void> deletePayee(String id) => _replace(id, null);

  /// Merges payee [sourceId] into [targetId] and deletes the source.
  /// Rule conditions that compare the payee with the source's name by
  /// equality then compare with the target's name, unless another payee
  /// still carries the source's name.
  Future<void> mergePayees(String sourceId, String targetId) async {
    if (sourceId == targetId) {
      return;
    }
    final source = await _payeeRepository.getPayeeById(sourceId);
    final target = await _payeeRepository.getPayeeById(targetId);
    if (source == null || target == null) {
      return;
    }
    await _replace(
      sourceId,
      targetId,
      afterDelete: () async {
        final sourceNameStillUsed = (await _payeeRepository.getAllPayees()).any(
          (p) => p.name.toLowerCase() == source.name.toLowerCase(),
        );
        if (!sourceNameStillUsed) {
          await renamePayeeConditions(
            _ruleRepository,
            from: source.name,
            to: target.name,
          );
        }
      },
    );
  }

  Future<void> _replace(
    String fromId,
    String? toId, {
    Future<void> Function()? afterDelete,
  }) {
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
          await afterDelete?.call();
        })
        .whenComplete(() => _undoService?.clear());
  }
}
