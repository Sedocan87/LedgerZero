# Repository Pattern Documentation

## Overview

The repository pattern in LedgerZero serves as an abstraction layer between the domain logic and the data sources (SQLite/Drift). It ensures that the business logic remains agnostic of the underlying database implementation.

## Architecture

### Domain Layer (`lib/domain/repositories/`)
- Defines abstract interfaces (contracts).
- Methods return **Domain Entities** (pure Dart objects).
- Independent of any data source libraries (no Drift dependencies).

### Data Layer (`lib/data/repositories/`)
- Implements the domain interfaces.
- Depends on **Drift DAOs** (`lib/data/database/daos/`).
- Handles mapping between **Drift Table Classes** and **Domain Entities**.
- Manages error handling and logging.

## Usage Patterns

### 1. Mapping
Repositories are responsible for converting data to and from the domain format.
- **Read**: `DriftTableData` -> `DomainEntity`
- **Write**: `DomainEntity` -> `DriftTableCompanion`

### 2. Error Handling
All repository methods must wrap database operations in `try-catch` blocks.
- **Log** the error using `Logger.error`.
- **Rethrow** as a custom `DatabaseException` (defined in `lib/core/errors/exceptions.dart`).

**Example:**
```dart
@override
Future<List<Account>> getAllAccounts() async {
  try {
    final accounts = await _dao.getAllAccounts();
    return accounts.map(_mapToDomain).toList();
  } catch (e, stackTrace) {
    Logger.error('Failed to fetch accounts', e, stackTrace);
    throw DatabaseException('Failed to fetch accounts', e);
  }
}
```

### 3. Caching Strategy
**Current Status:** No explicit memory caching layer is implemented.

**Reasoning:**
- **Local-First Architecture:** The SQLite database is local and highly performant.
- **Reactivity:** We use Drift's `watch()` streams to pipe data directly from the DB to the UI (via Riverpod). This ensures the UI always reflects the absolute source of truth.
- **Simplicity:** Introducing a memory cache alongside reactive DB streams introduces complexity (stale data, cache invalidation) with minimal performance gain for typical dataset sizes in personal finance.
- **SQLCipher:** Encryption is handled at the page level by SQLCipher; data in memory (Domain Entities) is unencrypted but transient.

**Exception:**
If specific heavy aggregations (e.g., reports over 10 years of data) prove slow, a specific memoization strategy or a materialized view table in SQLite should be considered before a generic repository cache.

## Performance Benchmarks

Performance is monitored via `test/benchmarks/repository_benchmark_test.dart`.
Key targets (on mid-range mobile devices):
- **Insert 1000 items**: < 500ms
- **Read 1000 items**: < 100ms

## Best Practices
- **Dependency Injection**: Always inject Repositories via Riverpod providers.
- **Streams**: Prefer `watch()` methods for UI data binding to ensure real-time updates.
- **Batching**: Use batch operations in DAOs (via `batch()`) for bulk inserts/updates when possible.
