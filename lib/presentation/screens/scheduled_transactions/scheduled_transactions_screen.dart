import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/widgets/scheduled_transaction_list_item.dart';

class ScheduledTransactionsScreen extends ConsumerWidget {
  const ScheduledTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledTransactionsAsync = ref.watch(scheduledTransactionsProvider);
    final payeeMapAsync = ref.watch(payeeMapProvider);
    final categoryMapAsync = ref.watch(categoryMapProvider);
    final accountMapAsync = ref.watch(accountMapProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scheduledTransactions),
      ),
      body: scheduledTransactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.calendar, size: 64, color: Theme.of(context).disabledColor),
                  const SizedBox(height: 16),
                  Text(l10n.noScheduledTransactions, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    l10n.createScheduledTransactionDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return ScheduledTransactionListItem(
                transaction: transaction,
                payeeName: payeeMapAsync.value?[transaction.payeeId],
                categoryName: categoryMapAsync.value?[transaction.categoryId],
                accountName: accountMapAsync.value?[transaction.accountId],
                onTap: () {
                   context.pushNamed('edit-scheduled-transaction', pathParameters: {'id': transaction.id});
                },
                onDelete: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.delete),
                      content: Text(l10n.deleteNoteConfirmationMessage), // Reusing message
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(scheduledTransactionControllerProvider).deleteScheduledTransaction(transaction.id);
                            Navigator.pop(context);
                          },
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('${l10n.error}: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           context.pushNamed('add-scheduled-transaction');
        },
        child: const Icon(AppIcons.add),
      ),
    );
  }
}
