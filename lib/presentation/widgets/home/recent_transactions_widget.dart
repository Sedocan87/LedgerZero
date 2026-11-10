import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_parts.dart';
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
    // Each amount is shown in its account's currency (Settings currency
    // while accounts are loading).
    final lookups = ref.watch(transactionLookupsProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
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
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.recentTransactions,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xl,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 26,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm + 2),
                        Text(
                          l10n.noRecentTransactions,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final (index, transaction) in transactions.indexed)
                    TransactionListItem(
                      transaction: transaction,
                      payeeName:
                          lookups.payeeLabel(transaction, l10n) ??
                          _memoOrNull(transaction),
                      categoryName: lookups.categoryLabel(transaction, l10n),
                      category: lookups.categoryOf(transaction),
                      isSplit: lookups.isSplit(transaction),
                      accountName:
                          lookups.accounts[transaction.accountId]?.name,
                      currencyCode: lookups.currencyOf(transaction),
                      // A glance at the latest rows: no cleared toggle.
                      showClearedStatus: false,
                      showDivider: index > 0,
                    ),
                ],
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

/// Without a payee, the memo says what the row is.
String? _memoOrNull(Transaction tx) {
  final memo = tx.memo?.trim();
  return memo == null || memo.isEmpty ? null : memo;
}
