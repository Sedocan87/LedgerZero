import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_filter_sheet.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsProvider);

    // Lookups for names
    final categories = ref.watch(categoryMapProvider).value ?? {};
    final payees = ref.watch(payeeMapProvider).value ?? {};
    final accounts = ref.watch(accountMapProvider).value ?? {};

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(state),
        leading: _buildAppBarLeading(state),
        actions: _buildAppBarActions(state, state.transactions.asData?.value),
      ),
      // Task 215: Pull-to-refresh
      body: RefreshIndicator(
        onRefresh: () => ref.read(transactionsProvider.notifier).refresh(),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: state.transactions.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return _buildEmptyState(context); // Task 209
              }

              final grouped = _groupTransactions(transactions);
              final flattened = _buildFlattenedList(grouped);

              // Task 219: ListView.builder for performance (Flattened)
              return ListView.builder(
                itemCount: flattened.length + 1, // +1 for load more button
                itemBuilder: (context, index) {
                  if (index == flattened.length) {
                    // Only show load more if we might have more transactions
                    if (transactions.length >= state.limit) {
                      return _buildLoadMoreButton(ref); // Task 208
                    } else {
                      return const SizedBox.shrink();
                    }
                  }

                  final item = flattened[index];
                  if (item is DateTime) {
                    return _buildDateHeader(context, item);
                  } else if (item is Transaction) {
                    return _buildTransactionItem(
                      context,
                      item,
                      payees,
                      categories,
                      accounts,
                      state,
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Transaction',
        onPressed: () {
          context.pushNamed('add-transaction');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Transaction tx,
    Map<String, String> payees,
    Map<String, String> categories,
    Map<String, String> accounts,
    TransactionsState state,
  ) {
    // Task 216: Swipe actions
    if (state.isMultiSelectMode) {
      // Disable dismissible in multi-select mode
      return TransactionListItem(
        transaction: tx,
        payeeName: payees[tx.payeeId],
        categoryName: categories[tx.categoryId],
        accountName: accounts[tx.accountId],
        isSelectionMode: true,
        isSelected: state.selectedTransactionIds.contains(tx.id),
        onTap: () {
          ref.read(transactionsProvider.notifier).toggleSelection(tx.id);
        },
        onLongPress: () {
          // Already in mode
        },
      );
    }

    return Dismissible(
      key: Key(tx.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.green,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Delete
          return true;
        } else {
          // Approve
          // ignore: unawaited_futures
          ref.read(transactionRepositoryProvider).updateTransaction(
                tx.copyWith(approved: true),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction approved')),
          );
          return false; // Don't remove from list
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          ref.read(transactionRepositoryProvider).deleteTransaction(tx.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Transaction deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  // ignore: unawaited_futures
                  ref
                      .read(transactionRepositoryProvider)
                      .updateTransaction(tx.copyWith(isDeleted: false));
                },
              ),
            ),
          );
        }
      },
      child: Focus(
        child: TransactionListItem(
          transaction: tx,
          payeeName: payees[tx.payeeId],
          categoryName: categories[tx.categoryId],
          accountName: accounts[tx.accountId],
          isSelectionMode: false,
          isSelected: false,
          onTap: () {
            context.pushNamed('edit-transaction', pathParameters: {'id': tx.id});
          },
          onLongPress: () {
            ref.read(transactionsProvider.notifier).toggleMultiSelectMode();
            ref.read(transactionsProvider.notifier).toggleSelection(tx.id);
          },
          onClearStatusChanged: (status) {
            final updated = tx.copyWith(cleared: status);
            // ignore: unawaited_futures
            ref.read(transactionRepositoryProvider).updateTransaction(updated);
          },
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(TransactionsState state) {
    if (state.isMultiSelectMode) {
      return Text('${state.selectedTransactionIds.length} Selected');
    }
    if (_isSearchMode) {
      return TextField(
        controller: _searchController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Search transactions...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white70),
        ),
        style: const TextStyle(color: Colors.white),
        onChanged: (value) {
          ref.read(transactionsProvider.notifier).updateSearchQuery(value);
        },
      );
    }
    return const Text('Transactions');
  }

  Widget? _buildAppBarLeading(TransactionsState state) {
    if (state.isMultiSelectMode) {
      return IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close selection',
          onPressed: () {
            ref.read(transactionsProvider.notifier).toggleMultiSelectMode();
          });
    }
    if (_isSearchMode) {
      return IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            setState(() {
              _isSearchMode = false;
              _searchController.clear();
              ref.read(transactionsProvider.notifier).updateSearchQuery('');
            });
          });
    }
    return null;
  }

  List<Widget> _buildAppBarActions(
      TransactionsState state, List<Transaction>? allTransactions) {
    if (state.isMultiSelectMode) {
      return [
        IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete selected',
            onPressed: () {
              // Task 218: Bulk delete
              final ids = state.selectedTransactionIds.toList();
              if (ids.isNotEmpty) {
                ref
                    .read(transactionRepositoryProvider)
                    .batchDeleteTransactions(ids);
                ref.read(transactionsProvider.notifier).toggleMultiSelectMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${ids.length} transactions deleted')),
                );
              }
            }),
        IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Approve selected',
            onPressed: () {
              // Task 218: Bulk approve
              final ids = state.selectedTransactionIds;
              if (ids.isNotEmpty && allTransactions != null) {
                final txsToApprove = allTransactions
                    .where((t) => ids.contains(t.id))
                    .map((t) => t.copyWith(approved: true))
                    .toList();
                if (txsToApprove.isNotEmpty) {
                  ref
                      .read(transactionRepositoryProvider)
                      .batchUpdateTransactions(txsToApprove);
                }
                ref.read(transactionsProvider.notifier).toggleMultiSelectMode();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('${ids.length} transactions approved')),
                );
              }
            }),
        IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Categorize selected',
            onPressed: () {
              // Task 218: Bulk categorize
              _showBulkCategorizeDialog(context, state);
            }),
        IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select all',
            onPressed: () {
              if (allTransactions != null) {
                ref
                    .read(transactionsProvider.notifier)
                    .selectAll(allTransactions.map((t) => t.id).toList());
              }
            }),
      ];
    }
    if (_isSearchMode) {
      return [
        IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear search',
            onPressed: () {
              _searchController.clear();
              ref.read(transactionsProvider.notifier).updateSearchQuery('');
            }),
      ];
    }
    return [
      IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () {
            setState(() {
              _isSearchMode = true;
            });
          }),
      // Task 491: Quick Add (Natural Language)
      IconButton(
        icon: const Icon(Icons.flash_on),
        tooltip: 'Quick Add',
        onPressed: () {
          context.pushNamed('quick-add');
        },
      ),
      // Task 211: Filtering
      IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
          onPressed: () {
            _showFilterDialog(context, state);
          }),
      // Task 214: Sorting
      PopupMenuButton<TransactionSortField>(
        icon: const Icon(Icons.sort),
        tooltip: 'Sort',
        onSelected: (field) {
          final currentSort = state.sort;
          final newAscending =
              currentSort.field == field ? !currentSort.ascending : true;
          ref.read(transactionsProvider.notifier).updateSort(
              TransactionSort(field: field, ascending: newAscending));
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: TransactionSortField.date,
            child: Text('Date'),
          ),
          const PopupMenuItem(
            value: TransactionSortField.amount,
            child: Text('Amount'),
          ),
          const PopupMenuItem(
            value: TransactionSortField.payeeName,
            child: Text('Payee'),
          ),
        ],
      ),
    ];
  }

  void _showFilterDialog(BuildContext context, TransactionsState state) {
    // Task 211 & 212: Filter UI
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TransactionFilterSheet(),
    );
  }

  void _showBulkCategorizeDialog(
      BuildContext context, TransactionsState state) {
    final categories = ref.read(categoryMapProvider).value ?? {};
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Categorize Selected'),
            content: SizedBox(
              width: double.maxFinite,
              child: categories.isEmpty
                  ? const Text('No categories found')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final catId = categories.keys.elementAt(index);
                        final catName = categories[catId]!;
                        return ListTile(
                          title: Text(catName),
                          onTap: () {
                            _bulkCategorize(
                                state.selectedTransactionIds, catId);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        });
  }

  void _bulkCategorize(Set<String> ids, String categoryId) {
    final allTxs =
        ref.read(transactionsProvider).transactions.asData?.value ?? [];
    final txsToUpdate = allTxs
        .where((t) => ids.contains(t.id))
        .map((t) => t.copyWith(categoryId: categoryId))
        .toList();

    if (txsToUpdate.isNotEmpty) {
      ref
          .read(transactionRepositoryProvider)
          .batchUpdateTransactions(txsToUpdate);
      ref.read(transactionsProvider.notifier).toggleMultiSelectMode();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions categorized')));
    }
  }

  Map<DateTime, List<Transaction>> _groupTransactions(
      List<Transaction> transactions) {
    final groups = <DateTime, List<Transaction>>{};
    for (var tx in transactions) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!groups.containsKey(date)) {
        groups[date] = [];
      }
      groups[date]!.add(tx);
    }
    return groups;
  }

  List<dynamic> _buildFlattenedList(Map<DateTime, List<Transaction>> grouped) {
    final list = <dynamic>[];
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (var date in sortedKeys) {
      list.add(date);
      list.addAll(grouped[date]!);
    }
    return list;
  }

  Widget _buildDateHeader(BuildContext context, DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      width: double.infinity,
      child: Text(
        DateFormat.yMMMEd().format(date),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 16),
          Text('No transactions found',
              style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ElevatedButton(
          onPressed: () {
            ref.read(transactionsProvider.notifier).loadMore();
          },
          child: const Text('Load More'),
        ),
      ),
    );
  }
}
