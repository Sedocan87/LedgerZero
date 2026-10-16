# Repository Pattern

How LedgerZero gets from the UI to the encrypted database, and where each
kind of code belongs.

```
presentation (Riverpod providers, screens)
  -> domain services (lib/domain/services)        multi-step business rules
    -> repository interfaces (lib/domain/repositories)
      <- repository implementations (lib/data/repositories)
        -> DAOs (lib/data/database/daos) -> AppDatabase (Drift on SQLCipher)
```

## Layers

### Domain: `lib/domain/repositories/`

* Abstract classes such as `AccountRepository`, `TransactionRepository`,
  `BudgetRepository`, `PayeeRepository`, `ScheduledTransactionRepository`.
* Methods take and return domain entities from `lib/domain/entities/`
  (plain Dart, no Drift types). Amounts are `int` minor units; dates are UTC
  (`CalendarDate` for calendar days).
* `unit_of_work.dart` defines `UnitOfWork` (see below) and
  `ImmediateUnitOfWork` (runs the action directly; only for unit tests with
  mocked repositories).
* `ReferenceMaintenanceRepository` holds the bulk reference rewrites used
  when categories, groups, accounts or payees are deleted or merged.

### Data: `lib/data/repositories/` and `lib/data/database/`

* `*RepositoryImpl` classes implement the interfaces. Most wrap one DAO
  (`AccountRepositoryImpl(AccountsDao)`, `TransactionRepositoryImpl(TransactionsDao)`, ...).
  `ReferenceMaintenanceRepositoryImpl` and `ImportProfileRepositoryImpl`
  take the `AppDatabase` directly because they work across tables.
* DAOs (`lib/data/database/daos/`) are Drift `DatabaseAccessor<AppDatabase>`
  classes that hold the queries, including the aggregate queries the budget
  maths is built on (for example `TransactionsDao.getReadyToAssignSum`,
  `getCategoryActivitySums`).
* Tables live in `lib/data/database/tables/`; `AppDatabase`
  (`lib/data/database/database.dart`) registers tables and DAOs, owns the
  migrations and the schema version (`AppDatabase.currentSchemaVersion`,
  currently 17). See [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md).
* Repositories map in both directions: Drift row data -> domain entity on
  read, domain entity -> `*Companion` on write.

### Domain services: `lib/domain/services/`

Any write that touches more than one row or table goes through a service,
not a repository called from a screen:

* `TransactionService` is the only writer of transactions (normal,
  transfer, split, delete, clear/approve, reconcile) and records undo actions.
* `BudgetingService` writes budget rows and computes TBB, activity,
  available and goal targets.
* `AccountService`, `CategoryService`, `PayeeService` handle deletes and
  merges together with `ReferenceMaintenanceRepository` and rule cleanup.
* `ScheduledTransactionService` materialises due occurrences.

Some services outside the domain layer (sync in `lib/services/sync/`,
backup/restore in `lib/services/backup/`) work on `AppDatabase` directly,
because they operate on whole tables and the sync bookkeeping tables.

## Unit of work

`UnitOfWork.run(action)` runs `action` atomically. The implementation
`DriftUnitOfWork` (`lib/data/database/drift_unit_of_work.dart`) calls
`AppDatabase.transaction`, so every repository and DAO call made inside the
callback joins the same transaction; nested `run` calls become savepoints.
If the action throws, all writes are rolled back and the error is rethrown.

```dart
await _unitOfWork.run(() async {
  await _writeBudget(fromCategoryId, month, (c) => c - amount);
  await _writeBudget(toCategoryId, month, (c) => c + amount);
});
```

Services receive the `UnitOfWork` through their constructor; tests with
mocked repositories pass `ImmediateUnitOfWork()`.

## Wiring (Riverpod)

There is no global database singleton. The chain is:

1. `databaseProvider` (`lib/presentation/providers/database_provider.dart`)
   opens `AppDatabase` with the session key once the app is unlocked. While
   locked it throws `DatabaseLockedException`. It is rebuilt when the key
   changes or `databaseGenerationProvider` is bumped (after a restore).
2. `*DaoProvider`s in the same file expose the DAOs of that database.
3. `lib/presentation/providers/repository_providers.dart` builds the
   repositories, `unitOfWorkProvider` and `referenceMaintenanceRepositoryProvider`.
4. `lib/presentation/providers/service_providers.dart` builds the services.

Because everything is derived from `databaseProvider`, a lock, unlock or
restore rebuilds the whole chain. Tests override `databaseProvider` with an
in-memory database (see `test/helpers/test_database.dart`).

## Reactivity

* Repositories expose `watch...()` streams backed by Drift `watch()` for
  lists (accounts, categories, payees, transactions, scheduled transactions).
* Derived numbers (TBB, available, reports) are computed on demand.
  `ledgerChangesProvider` emits a revision after every committed write to
  transactions, accounts, budgets, categories, category groups or payees;
  providers such as `tbbProvider` and `budgetViewModelProvider` watch it to
  recompute.
* There is no in-memory cache layer in the repositories.

## Error handling

Every repository implementation catches errors of its `Future` methods,
logs them with `Logger.error` (with the stack trace) and rethrows a
`DatabaseException` (`lib/core/errors/exceptions.dart`) that carries the
original error:

```dart
@override
Future<List<Account>> getAllAccounts() async {
  try {
    final rows = await _accountsDao.getAllAccountsWithBalance();
    return rows.map(_mapToDomain).toList();
  } catch (e, stackTrace) {
    Logger.error('Failed to fetch accounts', e, stackTrace);
    throw DatabaseException('Failed to fetch accounts', e);
  }
}
```

`test/data/repositories/repository_error_wrapping_test.dart` checks this
for the import profile, parsing history and rule repositories. `watch...()`
streams pass Drift errors through to the stream listener. New code should
use the pattern above. Screens show errors through `LoadErrorView` /
`ErrorView` with a localised message, never the exception text.

## Rules of thumb

* Screens and providers read through repositories, but write multi-row
  changes through a domain service inside a unit of work.
* Never store a balance or other derived value; compute it in a DAO query
  (account balance = starting balance + sum of non-deleted, non-split-child
  rows; see [docs/BUDGETING_RULES.md](docs/BUDGETING_RULES.md)).
* Use Drift `batch()` in DAOs for bulk inserts and updates.
* Performance tests live in `test/performance/` and are tagged `perf`
  (run with `bash tool/check.sh --perf`).
