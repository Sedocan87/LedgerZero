import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';

final recentTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
      final repository = ref.watch(transactionRepositoryProvider);
      return repository.watchTransactions(
        // A split is listed once, by its parent.
        filter: const TransactionFilter(excludeSplitChildren: true),
        sort: const TransactionSort(
          field: TransactionSortField.date,
          ascending: false,
        ),
        limit: 5,
      );
    });

class RecentTransactionsWidget extends ConsumerWidget {
  const RecentTransactionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);
    final fmt = ref.watch(appFormatterProvider);
    // Each amount is shown in its account's currency (Settings currency
    // while accounts are loading).
    final accountCurrencies = <String, String>{
      for (final account in ref.watch(accountsProvider).valueOrNull ?? [])
        account.id: account.currency,
    };
    final payeeNames = ref.watch(payeeMapProvider).valueOrNull ?? const {};
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.recentTransactions,
              style: theme.textTheme.titleLarge,
            ),
          ),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.noRecentTransactions,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: AppSpacing.xxl + AppSpacing.md, // Indent past icon
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final isIncome = transaction.amount >= 0;
                  final color = isIncome ? AppColors.income : AppColors.expense;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      payeeNames[transaction.payeeId] ??
                          transaction.memo ??
                          l10n.unknownPayee,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      fmt.formatDate(transaction.date),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: AmountText(
                      transaction.amount,
                      currencyCode: accountCurrencies[transaction.accountId],
                      amountContext: AmountContext.transaction,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) =>
                LoadErrorView(error: err, stackTrace: stack, compact: true),
          ),
        ],
      ),
    );
  }
}
