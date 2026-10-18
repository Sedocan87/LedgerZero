import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/providers/scheduled_transaction_provider.dart';
import 'package:ledger_zero/presentation/screens/scheduled_transactions/widgets/scheduled_transaction_list_item.dart';

class ScheduledTransactionsScreen extends ConsumerWidget {
  const ScheduledTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledTransactionsAsync = ref.watch(scheduledTransactionsProvider);
    final accounts =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    final accountNames = {for (final a in accounts) a.id: a.name};
    final accountCurrencies = {for (final a in accounts) a.id: a.currency};
    final closedAccountIds = {
      for (final a in accounts)
        if (a.isClosed) a.id,
    };
    final payeeNames = {
      for (final p in ref.watch(payeesProvider).valueOrNull ?? const <Payee>[])
        p.id: p.name,
    };
    final categoryNames = {
      for (final c
          in ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
        c.id: c.name,
    };
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.scheduledTransactions),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.upcoming),
              Tab(text: l10n.allTime),
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
                    Icon(
                      AppIcons.calendar,
                      size: 64,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.noScheduledTransactions,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
            final upcoming =
                transactions.where((t) => t.nextDate != null).toList()
                  ..sort((a, b) => a.nextDate!.compareTo(b.nextDate!));

            return TabBarView(
              children: [
                _TransactionList(
                  transactions: upcoming,
                  payeeMap: payeeNames,
                  categoryMap: categoryNames,
                  accountMap: accountNames,
                  accountCurrencies: accountCurrencies,
                  closedAccountIds: closedAccountIds,
                ),
                _TransactionList(
                  transactions: transactions,
                  payeeMap: payeeNames,
                  categoryMap: categoryNames,
                  accountMap: accountNames,
                  accountCurrencies: accountCurrencies,
                  closedAccountIds: closedAccountIds,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            Logger.error('Failed to load scheduled transactions', error, stack);
            return Center(child: Text(l10n.errorOccurred));
          },
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'scheduled-transactions-fab',
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
  final Map<String, String> accountCurrencies;
  final Set<String> closedAccountIds;

  const _TransactionList({
    required this.transactions,
    this.payeeMap,
    this.categoryMap,
    this.accountMap,
    this.accountCurrencies = const {},
    this.closedAccountIds = const {},
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
          currencyCode: accountCurrencies[transaction.accountId],
          accountClosed: closedAccountIds.contains(transaction.accountId),
          onTap: () {
            context.pushNamed(
              'edit-scheduled-transaction',
              pathParameters: {'id': transaction.id},
            );
          },
          onSkip: () => _run(
            context,
            () => ref
                .read(scheduledTransactionControllerProvider)
                .skipScheduledTransaction(transaction.id),
          ),
          onDelete: () => _confirmDelete(context, ref, transaction.id),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.scheduledDeleteConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await _run(
      context,
      () => ref
          .read(scheduledTransactionControllerProvider)
          .deleteScheduledTransaction(id),
    );
  }

  /// Runs [action]; failures are logged and reported with a friendly
  /// message.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context)!.scheduledActionFailed;
    try {
      await action();
    } catch (e, stack) {
      Logger.error('Scheduled transaction action failed', e, stack);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
