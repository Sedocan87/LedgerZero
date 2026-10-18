import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

/// The payees screen's search text. Both this and [filteredPayeesProvider]
/// are autoDispose: leaving the screen drops the filter, so it never comes
/// back filtered behind an empty search box.
final payeeSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final filteredPayeesProvider = Provider.autoDispose<AsyncValue<List<Payee>>>((
  ref,
) {
  final payeesAsync = ref.watch(payeesProvider);
  final query = ref.watch(payeeSearchQueryProvider).toLowerCase();

  return payeesAsync.whenData((payees) {
    final filtered = query.isEmpty
        ? [...payees]
        : payees.where((p) => p.name.toLowerCase().contains(query)).toList();

    // Sort by Favorite then Name
    filtered.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  });
});

final suggestedPayeesProvider = StreamProvider.autoDispose<List<Payee>>((ref) {
  final repository = ref.watch(payeeRepositoryProvider);
  return repository.watchSuggestedPayees();
});

/// One payee by id (null when it does not exist), following the payees
/// stream so edits, renames and deletes show immediately.
final payeeProvider = Provider.autoDispose.family<AsyncValue<Payee?>, String>(
  (ref, id) => ref
      .watch(payeesProvider)
      .whenData((payees) => payees.where((p) => p.id == id).firstOrNull),
);

/// The payee's transactions, newest first (split children included so the
/// list shows each categorised line; stats count a split once). Follows the
/// database, so new, edited and deleted transactions show immediately.
final payeeTransactionsProvider = StreamProvider.autoDispose
    .family<List<Transaction>, String>((ref, payeeId) {
      return ref
          .watch(transactionRepositoryProvider)
          .watchTransactions(
            filter: TransactionFilter(payeeIds: [payeeId]),
            sort: const TransactionSort(
              field: TransactionSortField.date,
              ascending: false,
            ),
          );
    });

class PayeeController {
  final Ref ref;

  PayeeController(this.ref);

  Future<void> updatePayee(Payee payee) async {
    await ref.read(payeeRepositoryProvider).updatePayee(payee);
  }

  /// Deletes a payee and clears every reference to it (atomic).
  Future<void> deletePayee(String id) async {
    Logger.info('Deleting payee $id');
    await ref.read(payeeServiceProvider).deletePayee(id);
  }

  /// Moves everything from [sourceId] to [targetId] and deletes the source
  /// (atomic).
  Future<void> mergePayees(String sourceId, String targetId) async {
    Logger.info('Merging payee $sourceId into $targetId');
    await ref.read(payeeServiceProvider).mergePayees(sourceId, targetId);
  }
}

final payeeControllerProvider = Provider((ref) => PayeeController(ref));
