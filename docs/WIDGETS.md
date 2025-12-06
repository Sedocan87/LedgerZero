# iOS & Android Widgets

## Overview

LedgerZero supports home screen and lock screen widgets (iOS 16+) to provide users with quick access to their budget information ("To Be Budgeted" and category balances).

## Architecture

Due to the "Local-First" and "Zero-Knowledge" architecture of LedgerZero, the database is encrypted using SQLCipher. The encryption key resides in memory only when the user has authenticated (via password or biometrics).

### The "Snapshot" Strategy

Because the Widget Extension runs in a separate process (or context) and does not have access to the user's session key, it cannot read from the SQLite database directly.

Instead, the main application:
1.  Calculates the necessary display data (TBB, Top Categories, Recent Transactions).
2.  Exports this non-sensitive summary data to a shared container (`UserDefaults` on iOS).
3.  The Widget reads this static JSON snapshot.

## Limitations

### 1. Update Frequency & "Staleness"
- **App Must Be Opened:** The widget data is only updated when the main application is running (foreground) or immediately upon backgrounding.
- **No Background Sync:** If you receive a transaction sync from another device in the background (which is currently limited by encryption anyway), the widget will *not* update until you open the app to decrypt and process the changes.
- **iOS Budget Limits:** iOS limits how often a widget can refresh. LedgerZero requests a reload when data changes, but the OS ultimately decides when to repaint the widget.

### 2. Privacy
- **Shared Storage:** The snapshot data (category names and balances) is stored in a shared container that is accessible to the Widget Extension. While the device filesystem is encrypted when locked, this data is theoretically less protected than the SQLCipher database.
- **Mitigation:** Only summary data is exported. Full transaction history is not exposed to the widget. Users who require absolute secrecy should not enable the widget.

### 3. Interactive Limitations
- **Read-Only:** Widgets are strictly read-only. Tapping a widget deep-links into the application (e.g., to the Budget or Transaction screen), requiring authentication before any actions can be taken.
- **No Quick Entry (Yet):** We do not currently support an "App Intent" for quick transaction entry from the widget without opening the main app, as this would require keeping the database key in a less secure state.

## Configuration

Users can customize which categories appear in the widget via **Settings > Widgets**. Up to 4 categories can be pinned. If none are pinned, the widget defaults to showing the top 4 active categories sorted by available balance.
