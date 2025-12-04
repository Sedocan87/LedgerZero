# Delta Schema Migration Plan

## Overview
As the application evolves, the database schema will change (adding columns, tables, etc.). The `SyncDelta` includes a `schemaVersion` field to handle these changes. This document outlines the strategy for handling schema version mismatches during synchronization.

## Strategy

### 1. Version Compatibility
*   **Forward Compatibility:** Older app versions attempting to read newer deltas.
*   **Backward Compatibility:** Newer app versions reading older deltas.

### 2. Forward Compatibility (Old App, New Delta)
*   If `delta.schemaVersion` > `current_db_schema_version`:
    *   **Strict Mode (Current):** The app should **skip** applying the delta and log a warning/error. It should prompt the user to update the app.
    *   **Lenient Mode (Future):** If the change is additive (e.g., new column), the old app *could* ignore the extra field. However, to ensure data consistency, we enforce an update.

### 3. Backward Compatibility (New App, Old Delta)
*   If `delta.schemaVersion` < `current_db_schema_version`:
    *   The app must handle missing fields.
    *   **Logic:** When converting `delta.data` to a database companion/entity:
        *   Use default values for missing columns.
        *   If a column was renamed, map the old name to the new name based on `delta.schemaVersion`.

### 4. Migration Steps (Developer Guide)

When modifying the database schema:

1.  **Increment Schema Version:** Update `schemaVersion` in `AppDatabase`.
2.  **Update Delta Generation:** The `SyncDelta` will automatically pick up the new `schemaVersion`.
3.  **Update Delta Application Logic (Replay Service):**
    *   In `DeltaReplayService` (to be implemented), check `delta.schemaVersion`.
    *   If `delta.schemaVersion` < `current`:
        *   Apply migration logic to `delta.data` before inserting/updating.
    *   Example:
        ```dart
        Map<String, dynamic> data = delta.data;
        if (delta.schemaVersion < 11) {
           // Column 'icon' was added in v11
           data['icon'] ??= 'default_icon';
        }
        ```

### 5. Version History

*   **v1-v10:** Initial schema.
*   **v11:** Current version (SyncLog, PendingSyncChanges added).
