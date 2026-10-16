# Offline Capabilities

LedgerZero is designed as a "Local-First" application. This means it is fully functional without an internet connection, and network connectivity is treated as an optional enhancement for synchronization rather than a requirement for operation.

## Core Philosophy

1.  **Local Database**: All data is stored in a local SQLite database (encrypted with SQLCipher). The UI reads from this local database, ensuring 0-latency access regardless of network status.
2.  **Offline Queue**: Every change to a synced table is captured by database triggers in the encrypted database (`pending_sync_changes`). It survives restarts and crashes.
3.  **Automatic Sync**: With a sync provider set up (and a frequency other than *Manual*), the app syncs after unlock, on resume, about 10 seconds after a change, periodically, and when connectivity returns.

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
1.  The change is immediately committed to the local database, and a trigger records it in `pending_sync_changes` (same transaction).
2.  At the next sync run, all recorded changes become one encrypted change file (AES-256-GCM with the key from your sync passphrase) in the app's outbox (`sync/outbox/`).
3.  While offline the run stops before uploading; the file stays in the outbox, and later changes are added to the next file.

### Synchronization Recovery
When the app is online again (and "Sync only on Wi-Fi" allows it for automatic syncs):
1.  The sync controller starts a run (connectivity regained, resume, timer or your *Sync Now*).
2.  Files in the outbox are uploaded in sequence order.
3.  New change files of your other devices are downloaded and applied in order; a file that cannot be applied is set aside (Sync settings shows it) without blocking the other devices.

### Conflict Resolution
Each row carries its last edit time (`updated_at`, UTC).
*   If you edit the same transaction offline on Device A and on Device B, the later edit wins on both devices after they sync.
*   If your edit on this device lost, it is listed under **Sync settings → Sync conflicts**, where you can keep your version or dismiss it.
*   A delete wins over an older edit and loses to a newer one.

## Data Persistence & Crash Recovery
*   **Persistence**: Captured changes live in the encrypted database; generated files in the outbox. Both persist across restarts and reboots.
*   **Crash Recovery**: Files are written atomically (temporary file, then rename) in the same database transaction that removes the captured changes, so a crash never loses a change or uploads a truncated file.

## Optimizations
*   **Squashing**: Several edits of the same row between two syncs are sent once, as the row's current state.
*   **Compression**: Change files are gzip-compressed before encryption.
*   **Snapshots**: Devices periodically upload an encrypted snapshot, so a new device does not replay the whole history.
*   **Wi-Fi Preference**: You can configure the app to sync only when connected to Wi-Fi to save cellular data.
