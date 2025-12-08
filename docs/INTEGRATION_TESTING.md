# Integration Testing Guide

This document describes the integration test suite for LedgerZero (Task 810). These tests run on a real device or simulator and verify the application's behavior from an end-user perspective.

## Running Tests

To run the full suite of integration tests:

```bash
flutter test integration_test
```

To run a specific test:

```bash
flutter test integration_test/offline_mode_test.dart
```

## Test Suite Overview

| Test File | Description | Task ID |
|-----------|-------------|---------|
| `offline_mode_test.dart` | Verifies offline UI indicators and behavior when connectivity is simulated as offline. | 801 |
| `sync_conflict_test.dart` | Simulates Last-Writer-Wins (LWW) resolution behavior by verifying database updates. | 802 |
| `backup_restore_test.dart` | Tests the creation of backup files via the `BackupService` within the running app context. | 803 |
| `performance_integration_test.dart` | Measures startup time and list scrolling performance. | 804 |
| `concurrency_test.dart` | Verifies data integrity under concurrent database write operations. | 805 |
| `security_test.dart` | Tests the password setup flow during onboarding. | 806 |
| `cross_platform_test.dart` | Verifies that the app launches and acknowledges the runtime platform. | 807 |
| `stress_test.dart` | Tests the app's stability when handling a large volume (1000+) of transactions. | 808 |
| `upgrade_test.dart` | Verifies that the database schema version matches the expected application version. | 809 |

## Infrastructure

### `test_utils.dart`

Contains helper functions for setting up the integration test environment:

*   `setupIntegrationTest`: Initializes the app with an in-memory database and mocked SharedPreferences. Allows overriding providers.
*   `completeOnboarding`: Automates the onboarding flow to get the app into the dashboard state.

## Notes

*   **Database:** Most tests use an in-memory Drift database (`NativeDatabase.memory()`) to ensure isolation and speed.
*   **Connectivity:** `offline_mode_test.dart` uses `Mockito` to override the `ConnectivityService` provider.
*   **Performance:** Performance tests output timeline data which can be analyzed using Flutter DevTools.
