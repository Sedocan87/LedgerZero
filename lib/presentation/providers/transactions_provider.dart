import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';

// State class for the Transactions Screen
class TransactionsState {
  final AsyncValue<List<Transaction>> transactions;
  final TransactionFilter filter;
  final TransactionSort sort;
  final String searchQuery;
  final bool isMultiSelectMode;
  final Set<String> selectedTransactionIds;
  final int limit;

  const TransactionsState({
    this.transactions = const AsyncLoading(),
    this.filter = const TransactionFilter(),
    this.sort = const TransactionSort(
      field: TransactionSortField.date,
      ascending: false,
    ),
    this.searchQuery = '',
    this.isMultiSelectMode = false,
    this.selectedTransactionIds = const {},
    this.limit = 50,
  });

  TransactionsState copyWith({
    AsyncValue<List<Transaction>>? transactions,
    TransactionFilter? filter,
    TransactionSort? sort,
    String? searchQuery,
    bool? isMultiSelectMode,
    Set<String>? selectedTransactionIds,
    int? limit,
  }) {
    return TransactionsState(
      transactions: transactions ?? this.transactions,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      searchQuery: searchQuery ?? this.searchQuery,
      isMultiSelectMode: isMultiSelectMode ?? this.isMultiSelectMode,
      selectedTransactionIds:
          selectedTransactionIds ?? this.selectedTransactionIds,
      limit: limit ?? this.limit,
    );
  }
}

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final Ref ref;
  StreamSubscription<List<Transaction>>? _subscription;

  TransactionsNotifier(this.ref) : super(const TransactionsState()) {
    _loadPrefs();
    _initStream();
  }

  Future<void> _loadPrefs() async {
    final prefs = ref.read(sharedPreferencesProvider);

    // Load Sort
    final sortFieldIdx = prefs.getInt('tx_sort_field');
    final sortAsc = prefs.getBool('tx_sort_asc');
    TransactionSort? loadedSort;
    if (sortFieldIdx != null && sortAsc != null) {
      if (sortFieldIdx >= 0 &&
          sortFieldIdx < TransactionSortField.values.length) {
        loadedSort = TransactionSort(
          field: TransactionSortField.values[sortFieldIdx],
          ascending: sortAsc,
        );
      }
    }

    // Load Filter
    TransactionFilter? loadedFilter;
    final filterJson = prefs.getString('tx_filter');
    if (filterJson != null) {
      try {
        final filterMap = jsonDecode(filterJson) as Map<String, dynamic>;
        loadedFilter = TransactionFilter.fromJson(filterMap);
      } catch (e) {
        // Ignore error
      }
    }

    if (loadedSort != null || loadedFilter != null) {
      state = state.copyWith(
        sort: loadedSort ?? state.sort,
        filter: loadedFilter ?? state.filter,
      );
      _initStream();
    }
  }

  void _initStream() {
    _subscription?.cancel();
    // Don't set loading here to avoid flicker on minor updates if desired,
    // but for filter changes it might be good.
    // For now, only set loading if we don't have data or if it's a major change?
    // Let's keep it simple.
    // state = state.copyWith(transactions: const AsyncLoading());

    TransactionFilter currentFilter = state.filter;
    if (state.searchQuery.isNotEmpty) {
      currentFilter = currentFilter.copyWith(memoSearch: state.searchQuery);
    }

    final stream = ref
        .read(transactionRepositoryProvider)
        .watchTransactions(
          filter: currentFilter,
          sort: state.sort,
          limit: state.limit,
        );

    _subscription = stream.listen(
      (data) {
        state = state.copyWith(transactions: AsyncData(data));
      },
      onError: (e, st) {
        state = state.copyWith(transactions: AsyncError(e, st));
      },
    );
  }

  void loadMore() {
    state = state.copyWith(limit: state.limit + 50);
    _initStream();
  }

  void updateFilter(TransactionFilter filter) {
    state = state.copyWith(filter: filter);

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('tx_filter', jsonEncode(filter.toJson()));

    _initStream();
  }

  void updateSort(TransactionSort sort) {
    state = state.copyWith(sort: sort);

    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt('tx_sort_field', sort.field.index);
    prefs.setBool('tx_sort_asc', sort.ascending);

    _initStream();
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _initStream();
  }

  void toggleMultiSelectMode() {
    state = state.copyWith(
      isMultiSelectMode: !state.isMultiSelectMode,
      selectedTransactionIds: {},
    );
  }

  void toggleSelection(String id) {
    final newSelection = Set<String>.from(state.selectedTransactionIds);
    if (newSelection.contains(id)) {
      newSelection.remove(id);
    } else {
      newSelection.add(id);
    }
    state = state.copyWith(selectedTransactionIds: newSelection);
  }

  void selectAll(List<String> ids) {
    state = state.copyWith(selectedTransactionIds: Set.from(ids));
  }

  void clearSelection() {
    state = state.copyWith(selectedTransactionIds: {});
  }

  Future<void> refresh() async {
    // Just re-init stream to ensure fresh fetch if needed,
    // although watchTransactions should handle DB updates.
    // This might be useful if something outside DB changed or forced reload.
    _initStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final transactionsProvider =
    StateNotifierProvider.autoDispose<TransactionsNotifier, TransactionsState>((
      ref,
    ) {
      return TransactionsNotifier(ref);
    });

// Helper providers for name lookups
final categoryMapProvider = StreamProvider.autoDispose<Map<String, String>>((
  ref,
) {
  return ref
      .watch(categoryRepositoryProvider)
      .watchAllCategories()
      .map((list) => {for (var item in list) item.id: item.name});
});

final payeeMapProvider = StreamProvider.autoDispose<Map<String, String>>((ref) {
  return ref
      .watch(payeeRepositoryProvider)
      .watchAllPayees()
      .map((list) => {for (var item in list) item.id: item.name});
});

final accountMapProvider = StreamProvider.autoDispose<Map<String, String>>((
  ref,
) {
  return ref
      .watch(accountRepositoryProvider)
      .watchAllAccounts()
      .map((list) => {for (var item in list) item.id: item.name});
});
