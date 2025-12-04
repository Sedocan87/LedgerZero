# Sync Architecture

LedgerZero implements a "Local-First" synchronization architecture using a Delta Log system.

## Overview

- **Local-First**: All changes are committed to the local SQLite database first.
- **Delta-Based**: Changes are captured as `SyncDelta` objects (INSERT/UPDATE/DELETE) via database triggers.
- **Cloud-Agnostic**: Supports Google Drive and iCloud Drive via file storage.
- **Conflict Resolution**: Last-Writer-Wins (LWW) based on UTC timestamps.

## Core Components

### 1. Database Triggers & Pending Changes
Database triggers (`AFTER INSERT/UPDATE/DELETE`) capture every change into the `pending_sync_changes` table. This ensures no change is missed, even if the app crashes immediately.

### 2. Delta Generation Service (`DeltaGenerationService`)
- Processes records from `pending_sync_changes`.
- Squashes multiple changes to the same record (e.g., INSERT + UPDATE -> INSERT).
- Generates `SyncDelta` JSON files compressed with GZIP (`.json.gz`).
- Assigns a monotonically increasing sequence number per device.
- Inserts a record into `sync_log` to track generated deltas.

### 3. Local Delta Queue (`LocalDeltaQueue`)
Manages local file storage for deltas:
- `deltas/`: Pending upload.
- `deltas/uploaded/`: Successfully uploaded (kept for 30 days).
- `deltas/incoming/`: Downloaded from remote.
- `deltas/applied/`: Successfully applied to local DB.

### 4. Sync Engine (`SyncEngine`)
Orchestrates the synchronization process:
1.  **Generate**: Calls `DeltaGenerationService` to create local deltas.
2.  **Upload**: Uploads pending deltas from `deltas/` to cloud.
3.  **Download**: Lists remote files, filters out already processed ones (checked against `sync_log`), and downloads new ones in batches.
4.  **Replay**: Applies downloaded deltas using `DeltaReplayService`.

### 5. Delta Replay Service (`DeltaReplayService`)
Applies incoming deltas to the local database.
- **Batch Processing**: Applies deltas in transactions for performance.
- **Conflict Resolution**:
    - Checks `pending_sync_changes`: If user is editing the same record, ignore remote.
    - Checks `LocalDeltaQueue`: If we have a generated but un-uploaded delta for the same record, compare timestamps. If local is newer, ignore remote.
    - Checks `updated_at`: If the local record in DB is newer than the delta timestamp, ignore remote.
- **Idempotency**: Uses `insertOnConflictUpdate` to safely re-apply deltas if needed.

## Key Features

### Incremental Sync
- The engine lists all remote files but only downloads those not present in the local `sync_log`.
- `SyncLog` tracks both locally generated and remotely applied deltas.

### Full Sync
- A "Full Sync" option bypasses the `sync_log` check and re-downloads/re-applies all remote deltas.
- Useful for data recovery or corruption fixes.

### Conflict Resolution Strategy
We employ a **Last-Writer-Wins (LWW)** strategy with **Local Priority**:
1.  If a local change is pending (user just edited), it always wins (remote delta ignored).
2.  If a local change was recently generated (in queue), we compare timestamps. Newer wins.
3.  If no pending change, we compare the local record's `updated_at` with the delta's timestamp. Newer wins.

### Performance Optimizations
- **Batching**: Changes are processed, uploaded, downloaded, and replayed in batches (e.g., 10 files at a time) to reduce overhead and improve responsiveness.
- **Compression**: GZIP compression reduces bandwidth usage.
- **Parallelism**: Downloads can happen in parallel (up to batch size).

## Retry & Error Handling
- **Exponential Backoff**: Background sync retries with increasing delays (2s, 4s, 8s...) upon failure.
- **Cancellation**: Sync can be cancelled by the user, stopping the process safely between batches.
