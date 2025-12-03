import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/widgets/scheduled_transaction_list_item.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';

class ScheduledTransactionsScreen extends ConsumerWidget {
  const ScheduledTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledTransactionsAsync = ref.watch(scheduledTransactionsProvider);
    final payeeMapAsync = ref.watch(payeeMapProvider);
    final categoryMapAsync = ref.watch(categoryMapProvider);
    final accountMapAsync = ref.watch(accountMapProvider);
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.scheduledTransactions),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.upcoming), // We need to add "upcoming" to ARB if not exists, checking ARB... "scheduledTransactions" exists.
              Tab(text: l10n.allTime), // "All Time" exists
            ],
          ),
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

            // Upcoming: Filter nextDate != null, Sort by nextDate
            final upcoming = transactions
                .where((t) => t.nextDate != null)
                .toList()
              ..sort((a, b) => a.nextDate!.compareTo(b.nextDate!));

            return TabBarView(
              children: [
                _TransactionList(
                  transactions: upcoming,
                  payeeMap: payeeMapAsync.value,
                  categoryMap: categoryMapAsync.value,
                  accountMap: accountMapAsync.value,
                ),
                _TransactionList(
                  transactions: transactions,
                  payeeMap: payeeMapAsync.value,
                  categoryMap: categoryMapAsync.value,
                  accountMap: accountMapAsync.value,
                ),
              ],
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
      ),
    );
  }
}

class _TransactionList extends ConsumerWidget {
  final List<ScheduledTransaction> transactions;
  final Map<String, String>? payeeMap;
  final Map<String, String>? categoryMap;
  final Map<String, String>? accountMap;

  const _TransactionList({
    required this.transactions,
    this.payeeMap,
    this.categoryMap,
    this.accountMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    if (transactions.isEmpty) {
      return Center(child: Text(l10n.noTransactions));
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return ScheduledTransactionListItem(
          transaction: transaction,
          payeeName: payeeMap?[transaction.payeeId],
          categoryName: categoryMap?[transaction.categoryId],
          accountName: accountMap?[transaction.accountId],
          onTap: () {
            context.pushNamed('edit-scheduled-transaction', pathParameters: {'id': transaction.id});
          },
          onSkip: () {
             ref.read(scheduledTransactionControllerProvider).skipScheduledTransaction(transaction.id);
          },
          onDelete: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.delete),
                content: Text(l10n.deleteNoteConfirmationMessage),
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
  }
}
