# Offline Capabilities

LedgerZero is designed as a "Local-First" application. This means it is fully functional without an internet connection, and network connectivity is treated as an optional enhancement for synchronization rather than a requirement for operation.

## Core Philosophy

1.  **Local Database**: All data is stored in a local SQLite database (encrypted with SQLCipher). The UI reads from this local database, ensuring 0-latency access regardless of network status.
2.  **Offline Queue**: Changes made while offline are captured as `SyncDelta` objects and stored in a persistent local queue (file system).
3.  **Automatic Sync**: When connectivity is restored, the application automatically attempts to upload pending changes and download remote updates.

## Offline Features

### Full Functionality
You can perform **all** of the following actions while completely offline:
*   Create, edit, and delete accounts.
*   Record transactions (income, expense, transfers).
*   Manage categories and budgets.
*   View reports and analytics.
*   Search and filter data.
*   Export data (CSV, PDF).

### Queuing Mechanism
When you make a change (e.g., add a transaction):
1.  The change is immediately committed to the local database.
2.  A `SyncDelta` is generated representing this change.
3.  If offline, this delta is saved as a JSON file (GZIP compressed) in the app's document directory (`deltas/`).
4.  The app continues to function normally.

### Synchronization Recovery
When the app detects an active internet connection (and "Sync only on Wi-Fi" conditions are met):
1.  The `SyncEngine` wakes up.
2.  It scans the `deltas/` directory for any pending files.
3.  It uploads them to your configured cloud provider (Google Drive or iCloud).
4.  It checks for new remote deltas from other devices and applies them.

### Conflict Resolution
Since LedgerZero uses a "Last-Writer-Wins" strategy with high-precision timestamps, conflicts are resolved automatically.
*   If you edit a transaction offline on Device A, and edit the *same* transaction offline on Device B:
*   When both devices sync, the edit with the later timestamp will prevail.
*   The system is designed to be eventually consistent.

## Data Persistence & Crash Recovery
*   **Persistence**: The offline queue is stored on the device's file system. It persists across app restarts and device reboots.
*   **Crash Recovery**: If the app crashes or is killed while offline, no data is lost. The database changes are already saved, and the delta queue files remain on disk. Upon next launch, the app will simply pick up where it left off.

## Optimizations
*   **Queue Pruning**: The app intelligently squashes redundant operations (e.g., multiple updates to the same record) to minimize data transfer when you reconnect.
*   **Compression**: All delta files are compressed to reduce storage and bandwidth usage.
*   **Wi-Fi Preference**: You can configure the app to sync only when connected to Wi-Fi to save cellular data.
