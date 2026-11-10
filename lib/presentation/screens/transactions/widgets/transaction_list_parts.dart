import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';
import 'package:ledger_zero/presentation/widgets/common/empty_state.dart';

/// Ids of all split parents (labelled "Split" in lists).
final splitParentIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchSplitParentIds();
});

/// The lookups every transaction list renders its rows with. A lookup that
/// is still loading or failed (e.g. while the app locks) is empty: rows
/// then show their fallbacks instead of throwing.
final transactionLookupsProvider = Provider.autoDispose<TransactionLookups>((
  ref,
) {
  return TransactionLookups(
    categories: {
      for (final c
          in ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
        c.id: c,
    },
    payees: ref.watch(payeeMapProvider).valueOrNull ?? const {},
    accounts: {
      for (final a
          in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
        a.id: a,
    },
    splitParents: ref.watch(splitParentIdsProvider).valueOrNull ?? const {},
  );
});

/// Name lookups for rendering transaction rows.
class TransactionLookups {
  const TransactionLookups({
    required this.categories,
    required this.payees,
    required this.accounts,
    required this.splitParents,
  });

  final Map<String, Category> categories;
  final Map<String, String> payees;
  final Map<String, Account> accounts;
  final Set<String> splitParents;

  bool isSplit(Transaction tx) => splitParents.contains(tx.id);

  /// The category [tx] is booked to; `null` for a transfer, a split parent
  /// or an uncategorised row.
  Category? categoryOf(Transaction tx) =>
      tx.transferAccountId != null || isSplit(tx)
      ? null
      : categories[tx.categoryId];

  /// Who the row is about: a transfer's direction and other account, else
  /// the payee (`null` without one).
  String? payeeLabel(Transaction tx, AppLocalizations l10n) {
    if (tx.transferAccountId == null) {
      return payees[tx.payeeId];
    }
    final other = accounts[tx.transferAccountId]?.name;
    if (other == null) {
      return l10n.transfer;
    }
    return tx.amount < 0
        ? l10n.transferToAccount(other)
        : l10n.transferFromAccount(other);
  }

  /// What the row is: "Transfer", "Split" or the category's name (`null`
  /// when uncategorised).
  String? categoryLabel(Transaction tx, AppLocalizations l10n) {
    if (tx.transferAccountId != null) {
      return l10n.transfer;
    }
    if (isSplit(tx)) {
      return l10n.split;
    }
    return categories[tx.categoryId]?.name;
  }

  /// The currency of [tx]'s account (`null`, the Settings currency, while
  /// accounts load).
  String? currencyOf(Transaction tx) => accounts[tx.accountId]?.currency;
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

/// The total of each day in [transactions] (a list sorted by date) whose
/// rows are all loaded and all in one currency, by day ([CalendarDate]).
///
/// The list is paged ([hasMore]): rows are ordered by date, so only the
/// last loaded day can continue on the next page, and it gets no total
/// until that page has arrived (a partial sum would be a wrong figure).
/// A day with rows in several currencies gets none either (amounts are
/// never converted).
Map<DateTime, ({int total, String? currency})> completeDayTotals(
  List<Transaction> transactions, {
  required bool hasMore,
  required String? Function(Transaction) currencyOf,
}) {
  final totals = <DateTime, int>{};
  final currencies = <DateTime, Set<String?>>{};
  for (final tx in transactions) {
    final day = CalendarDate.normalize(tx.date);
    totals[day] = (totals[day] ?? 0) + tx.amount;
    (currencies[day] ??= {}).add(currencyOf(tx));
  }
  if (hasMore && transactions.isNotEmpty) {
    totals.remove(CalendarDate.normalize(transactions.last.date));
  }
  return {
    for (final MapEntry(key: day, value: total) in totals.entries)
      if (currencies[day]!.length == 1)
        day: (total: total, currency: currencies[day]!.single),
  };
}

/// The heading above a day's rows: the weekday and date, and the day's
/// [total] on the right when it is known ([completeDayTotals]).
class TransactionDateHeader extends ConsumerWidget {
  const TransactionDateHeader({
    super.key,
    required this.date,
    this.total,
    this.currencyCode,
  });

  final DateTime date;

  /// Sum of the day's rows (minor units); `null` hides it.
  final int? total;

  /// Currency of [total]; `null` uses the Settings currency.
  final String? currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final style = _headerStyle(theme);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ref.watch(appFormatterProvider).formatWeekdayDate(date),
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (total != null) ...[
              const SizedBox(width: 12),
              AmountText(
                key: const Key('transactions.dayTotal'),
                total!,
                currencyCode: currencyCode,
                signed: true,
                style: style?.copyWith(fontFeatures: _tabularFigures),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Text of the day heading. Kept here so the theme's helpers (tabular
// figures, semantic colours) can replace it in one place.
const _tabularFigures = [FontFeature.tabularFigures()];

TextStyle? _headerStyle(ThemeData theme) =>
    theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

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
