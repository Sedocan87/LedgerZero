import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every query and hands out a stream the test controls.
class _RecordingRepository extends Fake implements TransactionRepository {
  final queries = <({TransactionFilter? filter, int? limit})>[];
  final controllers = <StreamController<List<Transaction>>>[];

  @override
  Stream<List<Transaction>> watchTransactions({
    TransactionFilter? filter,
    TransactionSort? sort,
    int? limit,
  }) {
    queries.add((filter: filter, limit: limit));
    final controller = StreamController<List<Transaction>>();
    controllers.add(controller);
    return controller.stream;
  }

  /// Emits [count] rows on the latest subscription.
  void emit(int count) => controllers.last.add([
    for (var i = 0; i < count; i++)
      Transaction(
        id: 't$i',
        accountId: 'a',
        date: DateTime.utc(2024, 1, 1),
        amount: -100,
      ),
  ]);
}

void main() {
  late _RecordingRepository repo;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = _RecordingRepository();
    container = ProviderContainer(
      overrides: [
        transactionRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appFormatterProvider.overrideWithValue(
          AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  TransactionsNotifier notifier() {
    container.listen(transactionsProvider, (_, _) {});
    return container.read(transactionsProvider.notifier);
  }

  testWidgets('subscribes exactly once on creation', (tester) async {
    notifier();
    expect(repo.queries, hasLength(1));
  });

  testWidgets('search is debounced: one query after typing pauses', (
    tester,
  ) async {
    final n = notifier();
    for (final text in ['c', 'co', 'cor', 'corn']) {
      n.updateSearchQuery(text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Still typing: only the initial subscription.
    expect(repo.queries, hasLength(1));
    expect(container.read(transactionsProvider).searchQuery, 'corn');

    await tester.pump(TransactionsNotifier.searchDebounce);
    expect(repo.queries, hasLength(2));
    expect(repo.queries.last.filter?.searchText, 'corn');

    // Clearing applies immediately.
    n.updateSearchQuery('');
    expect(repo.queries, hasLength(3));
  });

  testWidgets('loadMore asks for one page at a time and stops at the end', (
    tester,
  ) async {
    final n = notifier();
    const page = TransactionsNotifier.pageSize;

    // Nothing loaded yet: nothing to page.
    n.loadMore();
    expect(repo.queries, hasLength(1));

    repo.emit(page); // a full first page
    await tester.pump();
    n.loadMore();
    expect(repo.queries, hasLength(2));
    expect(repo.queries.last.limit, 2 * page);

    // Resting at the end of the list while the page is on its way.
    for (var i = 0; i < 10; i++) {
      n.loadMore();
    }
    expect(repo.queries, hasLength(2));

    repo.emit(page + 10); // last page was not full
    await tester.pump();
    n.loadMore();
    expect(repo.queries, hasLength(2));
    expect(n.hasMore, isFalse);
  });

  testWidgets('a new filter starts again from the first page', (tester) async {
    final n = notifier();
    repo.emit(TransactionsNotifier.pageSize);
    await tester.pump();
    n.loadMore();
    n.updateFilter(const TransactionFilter(accountIds: ['a']));
    expect(repo.queries.last.limit, TransactionsNotifier.pageSize);
    expect(repo.queries.last.filter?.accountIds, ['a']);
  });
}
