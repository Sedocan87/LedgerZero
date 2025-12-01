import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

final recentTransactionsProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchTransactions(
    sort: const TransactionSort(field: TransactionSortField.date, ascending: false),
    limit: 5,
  );
});

class RecentTransactionsWidget extends ConsumerWidget {
  const RecentTransactionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                l10n.recentTransactions,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: Text(l10n.noRecentTransactions)),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: transaction.amount >= 0 ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
                        child: Icon(
                          transaction.amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                          color: transaction.amount >= 0 ? Colors.green : Colors.red,
                          size: 16,
                        ),
                      ),
                      title: Text(
                        transaction.memo ?? 'Transaction',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(DateFormat.yMMMd().format(transaction.date)),
                      trailing: Text(
                        NumberFormat.simpleCurrency().format(transaction.amount),
                        style: TextStyle(
                          color: transaction.amount >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
