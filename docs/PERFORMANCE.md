# Performance

LedgerZero runs entirely on the device against an encrypted SQLite database,
so most performance work is about query shape and rebuild scope.

## Database

* **Aggregate in SQL, not in Dart.** Balances, TBB, category activity and
  report totals are `SUM` queries in the DAOs (e.g.
  `TransactionsDao.getReadyToAssignSum`, `getCategoryActivitySums`). Do not
  load all transactions to add them up.
* **No N+1 queries.** For per-category numbers use the batch methods
  (`BudgetingService.calculateBatchCategoryPerformance`,
  `calculateBatchGoalTargets`) rather than one query per category in a loop.
* **Batch writes.** Use Drift `batch()` in DAOs for bulk inserts/updates and
  run multi-step writes inside one `UnitOfWork` (one transaction, one
  commit).
* **Indexes.** Existing indexes include transactions on account, date,
  category and payee; budgets on month; payees on name and favourite. Check
  [DATABASE_SCHEMA.md](../DATABASE_SCHEMA.md) before adding a query that
  filters or sorts on another column.
* **Recompute on change, not on a timer.** Derived numbers watch
  `ledgerChangesProvider` (fires once per committed write to the ledger
  tables); lists use Drift `watch()` streams.

## Isolates

Use `compute()` / `Isolate.run` for CPU-heavy work. Current uses: CSV
parsing (`CsvImportService`) and the key derivation in the security code.

## Widgets

* Use `const` constructors wherever possible (enforced by the
  `prefer_const_*` lints).
* Watch the narrowest state: `ref.watch(provider.select((s) => s.field))`.
* Split large `build` methods into widget classes, not helper methods.
* Build long lists lazily (`ListView.builder` and similar);
  `test/performance/transaction_list_performance_test.dart` checks this for
  the transaction list.
* Charts are `CustomPaint` widgets; the pie, bar and multi-line charts sit
  in a `RepaintBoundary` (`BalanceTrendChart` does not yet). Do the same for
  new painters.
* Dispose controllers (`TextEditingController`, `AnimationController`,
  `FocusNode`) in `dispose()`.

## Measuring

* **Perf tests** in `test/performance/` are tagged `perf` and skipped by
  default. Run them with `bash tool/check.sh --perf`. They use generous time
  budgets to catch regressions such as an accidental N+1 query, not to
  benchmark:
  * `budget_performance_test.dart`: budget calculations on 10,000
    transactions and 50 categories;
  * `transaction_list_performance_test.dart`: building and scrolling a
    large transaction list;
  * `large_database_backup_test.dart`: encrypted backup of a
    10,000-transaction database.
* **Slow frames.** `PerformanceMonitor` (`lib/core/performance/`) is started
  in debug and profile builds and logs a warning for every frame whose total
  span exceeds 16 ms (only visible when logging is enabled for the flavour).
* **DevTools.** Profile on a real, preferably older device in profile mode;
  use the performance overlay and the CPU profiler. On the Android emulator
  you can reduce CPU cores to approximate low-end hardware.
