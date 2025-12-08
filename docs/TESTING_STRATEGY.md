# Testing Strategy

## Overview

This document outlines the testing strategy for LedgerZero to ensure code quality, reliability, and correctness. We employ a mix of unit, widget, and integration tests, following the testing pyramid principle.

## Testing Pyramid

### 1. Unit Tests (Core Logic)
- **Scope**: Individual functions, classes, and business logic.
- **Coverage Goal**: >80%
- **Location**: `test/domain/`, `test/core/`, `test/data/`
- **Focus**:
  - Budgeting algorithms (`budgeting_service_test.dart`)
  - Transaction calculations (`transaction_service_test.dart`)
  - Utilities (`date_utils_test.dart`, `currency_formatter_test.dart`)
  - Data mapping and serialization

### 2. Widget Tests (UI Components)
- **Scope**: Individual widgets and screens in isolation.
- **Location**: `test/presentation/`
- **Focus**:
  - Rendering correctness
  - User interactions (taps, inputs)
  - State updates
  - Mocks are used for providers and repositories.

### 3. Integration Tests (End-to-End)
- **Scope**: Complete user flows involving multiple screens and database.
- **Location**: `integration_test/`
- **Focus**:
  - Database persistence
  - Sync flows (mocked network)
  - Critical user journeys (e.g., Add Account -> Add Transaction -> Check Budget)

## Key Testing Areas

### Budgeting Engine
- **Files**: `test/domain/services/budgeting_service_test.dart`
- **Scenarios**:
  - TBB (To Be Budgeted) calculation
  - Rolling over overspending
  - Goal target calculations
  - Budget snapshots

### Transactions
- **Files**: `test/domain/services/transaction_service_test.dart`, `test/domain/services/transaction_service_edge_cases_test.dart`
- **Scenarios**:
  - CRUD operations
  - Split transactions (sum validation)
  - Transfers (atomicity)
  - Filtering and searching

### Utilities
- **Files**: `test/core/utils/`
- **Scenarios**:
  - Date manipulation (Month boundaries, formatting)
  - Currency formatting (Locales, negative handling)
  - Form validation logic

## Tools and Libraries

- **flutter_test**: Core testing framework.
- **mockito**: For mocking dependencies (Repositories, DAOs).
- **build_runner**: For generating mocks.
- **integration_test**: For on-device/emulator tests.

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/path/to/file_test.dart
```

### Run with coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```
