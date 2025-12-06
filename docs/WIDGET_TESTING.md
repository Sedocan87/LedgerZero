# Widget Testing with Encrypted Database

## Overview

LedgerZero uses SQLCipher to encrypt the local SQLite database. The encryption key is derived from the user's password or biometric credentials and stored in the secure hardware enclave. The key is only available in memory (`SecurityManager._sessionKey`) while the application is unlocked.

iOS Widgets run in a separate process (App Extension) and do not have access to the main application's memory space. Therefore, the widget cannot access the encrypted database directly because it does not possess the session key.

## Architecture Strategy

To support widgets while maintaining security, LedgerZero employs a "Snapshot" strategy:

1.  **Main App (Authenticated):** When the app is open and unlocked, it calculates the necessary display data (e.g., "To Be Budgeted" amount, top category balances).
2.  **Data Export:** This calculated, non-sensitive summary data is serialized (JSON) and written to a shared `UserDefaults` container (`group.com.ledgerzero.app`).
3.  **Widget (Unauthenticated):** The widget reads this pre-calculated data from `UserDefaults`. It performs no database operations and requires no encryption keys.

## Testing Procedure

Since automated UI tests for iOS Home Screen widgets are limited, manual verification and unit testing of the data export logic are required.

### 1. Verify Data Export Logic

Ensure that `WidgetService.updateWidgetData()` successfully writes to `HomeWidget` (which wraps `UserDefaults`).

**Unit Test:**
- Mock `BudgetingService` and repositories.
- Call `updateWidgetData()`.
- Verify that `HomeWidget.saveWidgetData` is called with the correct keys (`tbb_amount`, `categories_json`, etc.).
- Verify that the JSON payload structure matches what the Swift code expects.

### 2. Verify Security Isolation

The widget code (`LedgerZeroWidget.swift`) must **never** import or attempt to access the SQLite database directly.

**Code Review Check:**
- scan `ios/LedgerZeroWidget/LedgerZeroWidget.swift`.
- Ensure there are no imports related to SQLite or the main app's core logic.
- Confirm it only reads from `UserDefaults`.

### 3. Manual Verification Steps

1.  **Unlock App:** Open LedgerZero and unlock it.
2.  **Trigger Update:** Make a transaction or change a budget amount.
3.  **Background App:** Press the home button to background the app.
    - *Expected:* The app calls `updateWidgetData` immediately before suspending.
4.  **View Widget:** Check the widget on the home screen.
    - *Expected:* It reflects the latest changes.
5.  **Kill App:** Force close LedgerZero from the app switcher.
6.  **View Widget:** Check the widget again.
    - *Expected:* It still shows the last known state (cached in `UserDefaults`).
    - *Why:* The widget reads from `UserDefaults`, which persists even if the app is killed.
7.  **Lock Device:** Lock the phone screen.
8.  **View Lock Screen Widget:** (If added) Check the lock screen widget.
    - *Expected:* It displays the cached data.

## Privacy Considerations

The data stored in `UserDefaults` (TBB amount, category names/balances) is technically unencrypted in the shared container file, although the device filesystem itself is encrypted when the device is locked. This is a deliberate trade-off to enable widget functionality.

**Mitigation:**
- Only "summary" data is exported.
- Full transaction history is NOT exported.
- Users concerned about privacy of summary data can choose not to add the widget.
