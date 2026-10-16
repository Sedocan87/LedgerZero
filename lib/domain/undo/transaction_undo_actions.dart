import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

/// Undo/redo of any transaction write, recorded as row snapshots.
///
/// [before] and [after] map every touched transaction id to its full state
/// before and after the change; `null` means "did not exist" (created rows
/// have no `before`). Undo writes the `before` states back, redo the `after`
/// states, in one unit of work. A row that did not exist on one side is
/// soft-deleted when going to that side, so:
///
/// * undoing a create soft-deletes the rows and redo restores them (it
///   never re-INSERTs an id that still exists);
/// * undoing a delete restores every row that was deleted with it (both
///   transfer legs, all split children);
/// * undoing an edit restores the counterpart / children exactly.
class TransactionChangeSetAction implements ReversibleAction {
  TransactionChangeSetAction(
    this._repository,
    this._unitOfWork, {
    required Map<String, Transaction?> before,
    required Map<String, Transaction?> after,
  }) : before = Map.unmodifiable(before),
       after = Map.unmodifiable(after);

  final TransactionRepository _repository;
  final UnitOfWork _unitOfWork;

  final Map<String, Transaction?> before;
  final Map<String, Transaction?> after;

  /// Ids of all rows this change touched.
  Set<String> get ids => {...before.keys, ...after.keys};

  @override
  Future<void> undo() => _restore(before, after);

  @override
  Future<void> redo() => _restore(after, before);

  Future<void> _restore(
    Map<String, Transaction?> target,
    Map<String, Transaction?> other,
  ) async {
    final rows = <Transaction>[];
    for (final id in ids) {
      final state = target[id] ?? other[id]?.copyWith(isDeleted: true);
      if (state != null) {
        rows.add(state);
      }
    }
    // Parents before children (children reference their parent).
    rows.sort(
      (a, b) => (a.parentTransactionId == null ? 0 : 1).compareTo(
        b.parentTransactionId == null ? 0 : 1,
      ),
    );
    await _unitOfWork.run(() => _repository.upsertTransactions(rows));
  }
}
