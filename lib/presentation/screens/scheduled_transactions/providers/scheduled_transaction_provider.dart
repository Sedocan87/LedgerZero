import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

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
    // Its pending reminder must not fire any more.
    try {
      await ref
          .read(notificationServiceProvider)
          .cancelNotification(ScheduledTransactionService.reminderId(id));
    } catch (e, st) {
      Logger.error('Cancelling the reminder of $id failed', e, st);
    }
  }

  /// Skips the next occurrence; its reminder moves to the new next
  /// occurrence (or is cancelled when the schedule is finished).
  Future<void> skipScheduledTransaction(String id) =>
      ref.read(scheduledTransactionServiceProvider).skipOccurrence(id);
}

final scheduledTransactionControllerProvider = Provider(
  (ref) => ScheduledTransactionController(ref),
);
