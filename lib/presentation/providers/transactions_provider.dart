import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
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
    this.limit = TransactionsNotifier.pageSize,
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

/// A transaction list opened with a fixed filter (e.g. "activity of this
/// category this month" from the budget). It is never persisted, so the
/// Transactions tab keeps its own filter.
class FilteredTransactionsArgs {
  const FilteredTransactionsArgs({required this.filter, required this.title});

  final TransactionFilter filter;
  final String title;
}

/// The transaction list behind the Transactions screen.
///
/// Holds exactly one database subscription at a time; it is replaced when
/// the query (filter, sort, search, page size) changes and cancelled on
/// dispose. Search input is debounced ([searchDebounce]) so typing does not
/// re-query on every keystroke, and [loadMore] requests the next page only
/// after the previous page has arrived and was full.
class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final Ref ref;

  /// Whether filter and sort are saved to and restored from preferences
  /// (only the Transactions tab does this).
  final bool persist;

  static const int pageSize = 50;
  static const Duration searchDebounce = Duration(milliseconds: 300);

  StreamSubscription<List<Transaction>>? _subscription;
  Timer? _searchTimer;

  /// A larger page was requested and has not arrived yet.
  bool _pageRequested = false;

  /// The main Transactions tab: filter and sort persist across restarts.
  TransactionsNotifier(this.ref) : persist = true, super(_restoredState(ref)) {
    _subscribe();
  }

  /// A list with a fixed initial [filter] that is never persisted.
  TransactionsNotifier.fixed(this.ref, TransactionFilter filter)
    : persist = false,
      super(TransactionsState(filter: filter)) {
    _subscribe();
  }

  /// The saved filter and sort (SharedPreferences is synchronous, so the
  /// first subscription already uses them).
  static TransactionsState _restoredState(Ref ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    var restored = const TransactionsState();

    final sortFieldIdx = prefs.getInt('tx_sort_field');
    final sortAsc = prefs.getBool('tx_sort_asc');
    if (sortFieldIdx != null &&
        sortAsc != null &&
        sortFieldIdx >= 0 &&
        sortFieldIdx < TransactionSortField.values.length) {
      restored = restored.copyWith(
        sort: TransactionSort(
          field: TransactionSortField.values[sortFieldIdx],
          ascending: sortAsc,
        ),
      );
    }

    final filterJson = prefs.getString('tx_filter');
    if (filterJson != null) {
      try {
        restored = restored.copyWith(
          filter: TransactionFilter.fromJson(
            jsonDecode(filterJson) as Map<String, dynamic>,
          ),
        );
      } catch (e) {
        Logger.warning('Ignoring unreadable saved transaction filter');
      }
    }
    return restored;
  }

  /// Replaces the database subscription with one for the current query.
  void _subscribe() {
    _subscription?.cancel();

    // Splits are listed once, by their parent (its lines show up when
    // filtering by category); a search also finds a split through its
    // lines' memo, category and amount.
    var currentFilter = state.filter.copyWith(excludeSplitChildren: true);
    final query = state.searchQuery.trim();
    if (query.isNotEmpty) {
      // The query matches memo, payee and category names, and the amount
      // when it parses as money in the user's number format.
      final amount = ref.read(appFormatterProvider).parseAmount(query);
      currentFilter = currentFilter.withSearch(query, amount?.abs());
    }

    _subscription = ref
        .read(transactionRepositoryProvider)
        .watchTransactions(
          filter: currentFilter,
          sort: state.sort,
          limit: state.limit,
        )
        .listen(
          (data) {
            _pageRequested = false;
            state = state.copyWith(transactions: AsyncData(data));
          },
          onError: (Object e, StackTrace st) {
            _pageRequested = false;
            state = state.copyWith(transactions: AsyncError(e, st));
          },
        );
  }

  /// A new query starts again from the first page.
  void _requery() {
    _searchTimer?.cancel();
    _pageRequested = false;
    state = state.copyWith(limit: pageSize);
    _subscribe();
  }

  /// Whether more rows may exist beyond the loaded page.
  bool get hasMore {
    final loaded = state.transactions.valueOrNull;
    return loaded != null && loaded.length >= state.limit;
  }

  /// Requests the next page. Ignored while a requested page has not
  /// arrived yet, and when the last page was not full (nothing more).
  void loadMore() {
    if (_pageRequested || !hasMore) {
      return;
    }
    _pageRequested = true;
    state = state.copyWith(limit: state.limit + pageSize);
    _subscribe();
  }

  void updateFilter(TransactionFilter filter) {
    state = state.copyWith(filter: filter);

    if (persist) {
      final prefs = ref.read(sharedPreferencesProvider);
      unawaited(prefs.setString('tx_filter', jsonEncode(filter.toJson())));
    }

    _requery();
  }

  void updateSort(TransactionSort sort) {
    state = state.copyWith(sort: sort);

    if (persist) {
      final prefs = ref.read(sharedPreferencesProvider);
      unawaited(prefs.setInt('tx_sort_field', sort.field.index));
      unawaited(prefs.setBool('tx_sort_asc', sort.ascending));
    }

    _requery();
  }

  /// Updates the query text at once and re-queries after [searchDebounce]
  /// without further input. Clearing the search applies immediately.
  void updateSearchQuery(String query) {
    if (query == state.searchQuery) {
      return;
    }
    state = state.copyWith(searchQuery: query);
    _searchTimer?.cancel();
    if (query.trim().isEmpty) {
      _requery();
      return;
    }
    _searchTimer = Timer(searchDebounce, _requery);
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

  /// Pull-to-refresh: re-runs the query (the list also follows the
  /// database on its own).
  Future<void> refresh() async => _subscribe();

  @override
  void dispose() {
    _searchTimer?.cancel();
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

/// A non-persisted list for [FilteredTransactionsArgs] (keyed by the
/// args instance passed to the route).
final filteredTransactionsProvider = StateNotifierProvider.autoDispose
    .family<TransactionsNotifier, TransactionsState, FilteredTransactionsArgs>(
      (ref, args) => TransactionsNotifier.fixed(ref, args.filter),
    );
