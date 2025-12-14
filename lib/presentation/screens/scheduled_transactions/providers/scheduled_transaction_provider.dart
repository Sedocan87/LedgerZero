import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

final scheduledTransactionsProvider =
    StreamProvider<List<ScheduledTransaction>>((ref) {
      final repository = ref.watch(scheduledTransactionRepositoryProvider);
      return repository.watchAllScheduledTransactions();
    });

class ScheduledTransactionController {
  final Ref ref;

  ScheduledTransactionController(this.ref);

  Future<void> deleteScheduledTransaction(String id) async {
    final repository = ref.read(scheduledTransactionRepositoryProvider);
    await repository.deleteScheduledTransaction(id);
  }

  Future<void> skipScheduledTransaction(String id) async {
    final repository = ref.read(scheduledTransactionRepositoryProvider);
    await repository.skipScheduledTransaction(id);
  }
}

final scheduledTransactionControllerProvider = Provider(
  (ref) => ScheduledTransactionController(ref),
);
