import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/loading_indicator.dart';
import 'package:ledger_zero/presentation/widgets/common/error_view.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/presentation/widgets/charts/balance_trend_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/services/csv/transaction_export_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

final accountDetailProvider = StreamProvider.family.autoDispose<Account?, String>((ref, id) {
  return ref.watch(accountRepositoryProvider).watchAccount(id);
});

final accountTransactionsProvider = StreamProvider.family.autoDispose<List<Transaction>, String>((ref, accountId) {
  return ref.watch(transactionRepositoryProvider).watchTransactionsByAccount(accountId);
});

final payeesProvider = StreamProvider.autoDispose<List<Payee>>((ref) {
  return ref.watch(payeeRepositoryProvider).watchAllPayees();
});

class AccountDetailScreen extends ConsumerWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountDetailProvider(accountId));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: accountAsync.when(
          data: (account) => Text(account?.name ?? l10n.accountDetails),
          loading: () => Text(l10n.loading),
          error: (_, __) => Text(l10n.error),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.goNamed('edit-account',
                pathParameters: {'id': accountId}),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.deleteAccount),
                    content: Text(l10n.deleteAccountConfirmation),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancel)),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.delete)),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(accountRepositoryProvider)
                      .deleteAccount(accountId);
                  if (context.mounted) {
                    context.pop();
                  }
                }
              } else if (value == 'close') {
                final account = accountAsync.value;
                if (account != null) {
                  final updated = account.copyWith(isClosed: !account.isClosed);
                  await ref
                      .read(accountRepositoryProvider)
                      .updateAccount(updated);
                }
              } else if (value == 'reconcile') {
                context.goNamed('reconcile-account',
                    pathParameters: {'id': accountId});
              } else if (value == 'export') {
                final account = accountAsync.value;
                if (account != null) {
                  final transactions = await ref
                      .read(transactionRepositoryProvider)
                      .getTransactionsByAccount(accountId);

                  final payees =
                      await ref.read(payeeRepositoryProvider).getAllPayees();
                  final payeeMap = {for (var p in payees) p.id: p.name};

                  final categories = await ref
                      .read(categoryRepositoryProvider)
                      .getAllCategories();
                  final categoryMap = {for (var c in categories) c.id: c.name};

                  await TransactionExportService().exportTransactionsToCsv(
                    transactions: transactions,
                    payeeNames: payeeMap,
                    categoryNames: categoryMap,
                    accountNames: {account.id: account.name},
                    filenamePrefix:
                        'export_${account.name.replaceAll(' ', '_')}',
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reconcile',
                child: Text(l10n.reconcileAccount),
              ),
              PopupMenuItem(
                value: 'export',
                child: Text(l10n.exportToCsv),
              ),
              PopupMenuItem(
                value: 'close',
                child: Text(accountAsync.value?.isClosed == true
                    ? l10n.reopenAccount
                    : l10n.closeAccount),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(l10n.deleteAccount),
              ),
            ],
          ),
        ],
      ),
      body: accountAsync.when(
        data: (account) {
          if (account == null) {
            return Center(child: Text(l10n.accountNotFound));
          }
          return Column(
            children: [
              TransactionListChartWrapper(
                  accountId: accountId, startingBalance: account.startingBalance),
              Expanded(
                child: TransactionList(
                    accountId: accountId, currency: account.currency),
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (e, s) => ErrorView(title: l10n.error, message: e.toString()),
      ),
    );
  }
}

class TransactionListChartWrapper extends ConsumerWidget {
  final String accountId;
  final double startingBalance;
  const TransactionListChartWrapper({super.key, required this.accountId, required this.startingBalance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));
    return transactionsAsync.when(
      data: (transactions) => BalanceTrendChart(transactions: transactions, startingBalance: startingBalance),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class TransactionList extends ConsumerWidget {
  final String accountId;
  final String currency;

  const TransactionList({super.key, required this.accountId, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));
    final payeesAsync = ref.watch(payeesProvider);
    final l10n = AppLocalizations.of(context)!;

    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Center(child: Text(l10n.noTransactions));
        }

        return ListView.separated(
          itemCount: transactions.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final t = transactions[index];
            final payeeName = payeesAsync.valueOrNull
                    ?.firstWhereOrNull((p) => p.id == t.payeeId)
                    ?.name ??
                l10n.unknownPayee;

            final currencyFormatter =
                NumberFormat.simpleCurrency(name: currency);

            return ListTile(
              title: Text(t.memo ?? payeeName),
              subtitle: Text(DateFormat.yMMMd().format(t.date)),
              trailing: Text(
                currencyFormatter.format(t.amount),
                style: TextStyle(
                  color: t.amount < 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
      loading: () => const LoadingIndicator(),
      error: (e, s) => ErrorView(title: l10n.error, message: e.toString()),
    );
  }
}
