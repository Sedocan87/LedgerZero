import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/undo/transaction_undo_actions.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_dialogs.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/pickers.dart';
import 'package:ledger_zero/presentation/widgets/common/load_error_view.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_filter_sheet.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_parts.dart';
import 'package:ledger_zero/presentation/widgets/common/settings_action.dart';

/// Ids of all split parents (labelled "Split" in lists).
final splitParentIdsProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchSplitParentIds();
});

/// The transaction list: the Transactions tab (persisted filter and sort),
/// or a list with a [fixedFilter] (e.g. a category's activity from the
/// budget) that never touches the tab's saved filter.
///
/// Every write goes through [TransactionService]: deleting a row deletes
/// its transfer counterpart or whole split after a confirmation, and Undo
/// restores everything that was deleted.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.fixedFilter});

  final FilteredTransactionsArgs? fixedFilter;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AutoDisposeStateNotifierProvider<TransactionsNotifier, TransactionsState>
  get _provider => widget.fixedFilter == null
      ? transactionsProvider
      : filteredTransactionsProvider(widget.fixedFilter!);

  TransactionService get _service => ref.read(transactionServiceProvider);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Near the end of the list: ask for the next page (the notifier ignores
  /// this while a page is on its way or when there is nothing more).
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      ref.read(_provider.notifier).loadMore();
    }
  }

  void _showMessage(String text, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text), action: action));
  }

  /// Runs a service call; a reconciled row needs the user's confirmation.
  Future<T?> _guarded<T>(
    Future<T> Function(bool allowReconciledChange) call,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      try {
        return await call(false);
      } on ReconciledTransactionException {
        if (!mounted || !await confirmReconciledChange(context)) {
          return null;
        }
        return await call(true);
      }
    } catch (e, stackTrace) {
      Logger.error('Transaction action failed', e, stackTrace);
      if (mounted) {
        _showMessage(l10n.txActionFailed);
      }
      return null;
    }
  }

  /// Confirms and deletes [ids] with everything linked to them; offers Undo.
  Future<void> _delete(List<String> ids) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final preview = await _service.previewDeletion(ids);
      if (!mounted || preview.rowCount == 0) {
        return;
      }
      final confirmed = await confirmTransactionDeletion(
        context,
        selectedCount: ids.length,
        preview: preview,
      );
      if (!confirmed || !mounted) {
        return;
      }
      final action = await _service.deleteMany(
        ids,
        // The dialog already warned about reconciled rows.
        allowReconciledChange: true,
      );
      if (action == null || !mounted) {
        return;
      }
      _showMessage(
        l10n.txDeletedCount(ids.length),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => _undo(action),
        ),
      );
    } catch (e, stackTrace) {
      Logger.error('Deleting transactions failed', e, stackTrace);
      if (mounted) {
        _showMessage(l10n.txActionFailed);
      }
    }
  }

  Future<void> _undo(TransactionChangeSetAction action) async {
    try {
      await ref.read(undoServiceProvider).undo(action);
    } catch (e, stackTrace) {
      Logger.error('Undo failed', e, stackTrace);
      if (mounted) {
        _showMessage(AppLocalizations.of(context)!.txActionFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(_provider);
    final lookups = TransactionLookups(
      categories: ref.watch(categoryMapProvider).valueOrNull ?? {},
      payees: ref.watch(payeeMapProvider).valueOrNull ?? {},
      accounts: {
        for (final a
            in ref.watch(accountsProvider).valueOrNull ?? const <Account>[])
          a.id: a,
      },
      splitParents: ref.watch(splitParentIdsProvider).valueOrNull ?? const {},
    );

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(state, l10n),
        leading: _buildAppBarLeading(state),
        actions: _buildAppBarActions(state, state.transactions.asData?.value),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(_provider.notifier).refresh(),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: state.transactions.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                final filtered =
                    state.searchQuery.trim().isNotEmpty ||
                    (widget.fixedFilter == null && state.filter.isActive);
                return TransactionsEmptyState(
                  filtered: filtered,
                  onAdd: widget.fixedFilter == null
                      ? () => context.pushNamed('add-transaction')
                      : null,
                  onClearFilters: _clearSearchAndFilter,
                );
              }
              final flattened = flattenByDay(transactions);
              return ListView.builder(
                controller: _scrollController,
                itemCount: flattened.length + 1,
                itemBuilder: (context, index) {
                  if (index == flattened.length) {
                    return ref.read(_provider.notifier).hasMore
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }
                  final item = flattened[index];
                  if (item is DateTime) {
                    return TransactionDateHeader(date: item);
                  }
                  return _buildTransactionItem(
                    item as Transaction,
                    lookups,
                    state,
                    l10n,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => LoadErrorView(
              error: e,
              stackTrace: st,
              onRetry: () => ref.read(_provider.notifier).refresh(),
            ),
          ),
        ),
      ),
      floatingActionButton: widget.fixedFilter != null
          ? null
          : FloatingActionButton(
              heroTag: 'transactions-fab',
              tooltip: l10n.addTransaction,
              onPressed: () => context.pushNamed('add-transaction'),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildTransactionItem(
    Transaction tx,
    TransactionLookups lookups,
    TransactionsState state,
    AppLocalizations l10n,
  ) {
    final otherAccount = lookups.accounts[tx.transferAccountId]?.name ?? '';
    final payeeName = tx.transferAccountId != null
        ? (tx.amount < 0
              ? l10n.transferToAccount(otherAccount)
              : l10n.transferFromAccount(otherAccount))
        : lookups.payees[tx.payeeId];
    final categoryName = tx.transferAccountId != null
        ? l10n.transfer
        : lookups.splitParents.contains(tx.id)
        ? l10n.split
        : lookups.categories[tx.categoryId];
    final item = TransactionListItem(
      transaction: tx,
      payeeName: payeeName,
      categoryName: categoryName,
      accountName: lookups.accounts[tx.accountId]?.name,
      currencyCode: lookups.accounts[tx.accountId]?.currency,
      isSelectionMode: state.isMultiSelectMode,
      isSelected: state.selectedTransactionIds.contains(tx.id),
      onTap: state.isMultiSelectMode
          ? () => ref.read(_provider.notifier).toggleSelection(tx.id)
          : () => context.pushNamed(
              'edit-transaction',
              pathParameters: {'id': tx.id},
            ),
      onLongPress: state.isMultiSelectMode
          ? null
          : () {
              ref.read(_provider.notifier).toggleMultiSelectMode();
              ref.read(_provider.notifier).toggleSelection(tx.id);
            },
      onClearStatusChanged: (status) => _guarded(
        (allow) => _service.updateClearingStatus(
          tx.id,
          status,
          allowReconciledChange: allow,
        ),
      ),
    );
    if (state.isMultiSelectMode) {
      return item;
    }
    return Dismissible(
      key: Key(tx.id),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.check_rounded, color: Colors.white),
      ),
      // The row is never removed by the Dismissible itself: the list
      // updates from the database once the service has written.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _delete([tx.id]);
        } else {
          await _guarded((_) => _service.approveTransaction(tx.id));
        }
        return false;
      },
      child: Focus(child: item),
    );
  }

  Widget _buildAppBarTitle(TransactionsState state, AppLocalizations l10n) {
    if (state.isMultiSelectMode) {
      return Text(l10n.selectedCount(state.selectedTransactionIds.length));
    }
    if (_isSearchMode) {
      return TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.txSearchHint,
          border: InputBorder.none,
        ),
        onChanged: (value) =>
            ref.read(_provider.notifier).updateSearchQuery(value),
      );
    }
    return Text(widget.fixedFilter?.title ?? l10n.transactions);
  }

  Widget? _buildAppBarLeading(TransactionsState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state.isMultiSelectMode) {
      return IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.closeSelection,
        onPressed: () => ref.read(_provider.notifier).toggleMultiSelectMode(),
      );
    }
    if (_isSearchMode) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: l10n.back,
        onPressed: () {
          setState(() {
            _isSearchMode = false;
            _searchController.clear();
          });
          ref.read(_provider.notifier).updateSearchQuery('');
        },
      );
    }
    return null;
  }

  List<Widget> _buildAppBarActions(
    TransactionsState state,
    List<Transaction>? allTransactions,
  ) {
    final notifier = ref.read(_provider.notifier);
    final l10n = AppLocalizations.of(context)!;
    if (state.isMultiSelectMode) {
      final ids = state.selectedTransactionIds.toList();
      return [
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: l10n.deleteSelected,
          onPressed: ids.isEmpty
              ? null
              : () async {
                  await _delete(ids);
                  if (mounted) {
                    notifier.toggleMultiSelectMode();
                  }
                },
        ),
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: l10n.approveSelected,
          onPressed: ids.isEmpty
              ? null
              : () async {
                  await _guarded((_) => _service.bulkApprove(ids));
                  if (mounted) {
                    notifier.toggleMultiSelectMode();
                  }
                },
        ),
        IconButton(
          icon: const Icon(Icons.folder),
          tooltip: l10n.categorizeSelected,
          onPressed: ids.isEmpty ? null : () => _showBulkCategorizeDialog(ids),
        ),
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: l10n.selectAll,
          onPressed: allTransactions == null
              ? null
              : () => notifier.selectAll(
                  allTransactions.map((t) => t.id).toList(),
                ),
        ),
      ];
    }
    if (_isSearchMode) {
      return [
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: l10n.clearSearch,
          onPressed: () {
            _searchController.clear();
            notifier.updateSearchQuery('');
          },
        ),
      ];
    }
    return [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: l10n.search,
        onPressed: () => setState(() => _isSearchMode = true),
      ),
      if (widget.fixedFilter == null)
        IconButton(
          icon: const Icon(Icons.flash_on),
          tooltip: l10n.quickAdd,
          onPressed: () => context.pushNamed('quick-add'),
        ),
      IconButton(
        icon: const Icon(Icons.filter_list),
        tooltip: l10n.filter,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => TransactionFilterSheet(
            initialFilter: state.filter,
            onApply: notifier.updateFilter,
          ),
        ),
      ),
      PopupMenuButton<TransactionSortField>(
        icon: const Icon(Icons.sort),
        tooltip: l10n.sort,
        onSelected: (field) {
          final current = state.sort;
          notifier.updateSort(
            TransactionSort(
              field: field,
              ascending: current.field == field ? !current.ascending : true,
            ),
          );
        },
        itemBuilder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return [
            PopupMenuItem(
              value: TransactionSortField.date,
              child: Text(l10n.date),
            ),
            PopupMenuItem(
              value: TransactionSortField.amount,
              child: Text(l10n.amount),
            ),
            PopupMenuItem(
              value: TransactionSortField.payeeName,
              child: Text(l10n.payee),
            ),
          ];
        },
      ),
      const SettingsAction(),
    ];
  }

  /// Clears the search text and (on the Transactions tab) the filter.
  void _clearSearchAndFilter() {
    final notifier = ref.read(_provider.notifier);
    _searchController.clear();
    setState(() => _isSearchMode = false);
    notifier.updateSearchQuery('');
    if (widget.fixedFilter == null) {
      notifier.updateFilter(const TransactionFilter());
    }
  }

  /// Picks a category with the searchable picker and assigns it to [ids].
  Future<void> _showBulkCategorizeDialog(List<String> ids) async {
    final category = await showCategoryPicker(context);
    if (category == null || !mounted) {
      return;
    }
    await _guarded((_) => _service.bulkCategorize(ids, category.id));
    if (mounted) {
      ref.read(_provider.notifier).toggleMultiSelectMode();
    }
  }
}
