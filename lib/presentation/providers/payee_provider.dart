import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

final payeesProvider = StreamProvider<List<Payee>>((ref) {
  final repository = ref.watch(payeeRepositoryProvider);
  return repository.watchAllPayees();
});

final payeeSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredPayeesProvider = Provider<AsyncValue<List<Payee>>>((ref) {
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

final payeeProvider = FutureProvider.family<Payee?, String>((ref, id) {
  final repository = ref.watch(payeeRepositoryProvider);
  return repository.getPayeeById(id);
});

final payeeTransactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, payeeId) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getTransactions(
    filter: TransactionFilter(payeeIds: [payeeId]),
    sort: const TransactionSort(field: TransactionSortField.date, ascending: false),
  );
});

class PayeeController {
  final Ref ref;

  PayeeController(this.ref);

  Future<void> updatePayee(Payee payee) async {
    await ref.read(payeeRepositoryProvider).updatePayee(payee);
  }

  Future<void> deletePayee(String id) async {
    final transactionRepo = ref.read(transactionRepositoryProvider);
    final payeeRepo = ref.read(payeeRepositoryProvider);

    // Fetch transactions for this payee
    final filter = TransactionFilter(payeeIds: [id]);
    final transactions = await transactionRepo.getTransactions(filter: filter);

    if (transactions.isNotEmpty) {
      Logger.info('Clearing payee from ${transactions.length} transactions before deleting payee $id');
      final updatedTransactions = transactions.map((t) {
        return Transaction(
          id: t.id,
          accountId: t.accountId,
          date: t.date,
          amount: t.amount,
          payeeId: null, // Clear payee
          categoryId: t.categoryId,
          memo: t.memo,
          cleared: t.cleared,
          approved: t.approved,
          isDeleted: t.isDeleted,
          transferAccountId: t.transferAccountId,
          transferTransactionId: t.transferTransactionId,
          parentTransactionId: t.parentTransactionId,
          createdAt: t.createdAt,
          updatedAt: DateTime.now(),
        );
      }).toList();

      await transactionRepo.batchUpdateTransactions(updatedTransactions);
    }

    await payeeRepo.deletePayee(id);
  }

  Future<void> mergePayees(String sourceId, String targetId) async {
    final transactionRepo = ref.read(transactionRepositoryProvider);
    final payeeRepo = ref.read(payeeRepositoryProvider);
    final sourcePayee = await payeeRepo.getPayeeById(sourceId);

    if (sourcePayee == null) {
      return;
    }

    // 1. Get transactions for source payee
    final filter = TransactionFilter(payeeIds: [sourceId]);
    final transactions = await transactionRepo.getTransactions(filter: filter);

    if (transactions.isNotEmpty) {
      Logger.info('Merging ${transactions.length} transactions from $sourceId to $targetId');

      // 2. Update transactions to target payee
      final updatedTransactions = transactions.map((t) {
        return t.copyWith(payeeId: targetId);
      }).toList();

      await transactionRepo.batchUpdateTransactions(updatedTransactions);
    }

    // 3. Delete source payee
    await payeeRepo.deletePayee(sourceId);
  }
}

final payeeControllerProvider = Provider((ref) => PayeeController(ref));
