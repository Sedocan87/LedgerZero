import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/empty_state.dart';

/// Name lookups for rendering transaction rows.
class TransactionLookups {
  const TransactionLookups({
    required this.categories,
    required this.payees,
    required this.accounts,
    required this.splitParents,
  });

  final Map<String, String> categories;
  final Map<String, String> payees;
  final Map<String, Account> accounts;
  final Set<String> splitParents;
}

/// The rows of a transaction list in the order the query returned them,
/// with a date header (a [DateTime]) before each day's rows when the list
/// is sorted by date. Any other order has no headers (every row shows its
/// date): grouping by day would undo the order the user asked for.
List<Object> flattenByDay(
  List<Transaction> transactions, {
  TransactionSort sort = const TransactionSort(
    field: TransactionSortField.date,
    ascending: false,
  ),
}) {
  if (sort.field != TransactionSortField.date) {
    return transactions;
  }
  final items = <Object>[];
  DateTime? current;
  for (final tx in transactions) {
    final day = CalendarDate.normalize(tx.date);
    if (day != current) {
      items.add(day);
      current = day;
    }
    items.add(tx);
  }
  return items;
}

class TransactionDateHeader extends ConsumerWidget {
  const TransactionDateHeader({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ref.watch(appFormatterProvider).formatWeekdayDate(date),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty transaction list: nothing recorded yet (offers adding one), or
/// nothing matching the search/filter (offers clearing them).
class TransactionsEmptyState extends StatelessWidget {
  const TransactionsEmptyState({
    super.key,
    this.filtered = false,
    this.onAdd,
    this.onClearFilters,
  });

  /// A search or filter is active.
  final bool filtered;
  final VoidCallback? onAdd;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(
      icon: filtered ? Icons.search_off : Icons.receipt_long,
      title: filtered ? l10n.noMatchingTransactions : l10n.noTransactions,
      description: filtered
          ? l10n.noMatchingTransactionsMessage
          : l10n.emptyTransactionsMessage,
      actionLabel: filtered ? l10n.clearFilters : l10n.addTransaction,
      onAction: filtered ? onClearFilters : onAdd,
    );
  }
}
