# Delta File Format Specification

## Overview
LedgerZero uses a file-based synchronization mechanism. Changes are propagated via "Delta" files, which are JSON files (compressed with GZIP) representing atomic changes to the database.

## Filename Convention
Deltas are named using the following pattern to ensure uniqueness and chronological ordering:

```
{timestamp_ms}_{deviceUuid}_{sequence}.json.gz
```

*   `timestamp_ms`: Epoch timestamp in milliseconds when the delta was generated.
*   `deviceUuid`: Unique identifier of the device generating the delta.
*   `sequence`: Monotonically increasing integer per device.

## JSON Structure

The uncompressed JSON content has the following structure:

```json
{
  "timestamp": "ISO-8601 String (UTC)",
  "deviceUUID": "String",
  "sequence": Integer,
  "action": "INSERT" | "UPDATE" | "DELETE",
  "table": "String (table name)",
  "schemaVersion": Integer,
  "appVersion": "String",
  "data": {
    "key": "value",
    ...
  },
  "checksum": "SHA-256 Hash"
}
```

### Fields

*   `timestamp`: The time when the change occurred. Used for "Last Writer Wins" conflict resolution.
*   `deviceUUID`: Identifies the source.
*   `sequence`: Ensures ordered application of deltas from the same device.
*   `action`: The type of change.
    *   `INSERT`: `data` contains the full record.
    *   `UPDATE`: `data` contains the full record (snapshot).
    *   `DELETE`: `data` contains at least the `id` of the record to delete.
*   `table`: The name of the table affected (e.g., `transactions`, `accounts`).
*   `schemaVersion`: The database schema version at the time of generation.
*   `appVersion`: The app version.
*   `data`: The payload. Keys correspond to database columns.
*   `checksum`: SHA-256 hash of the JSON content (excluding the checksum field itself) to ensure integrity.

## Checksum Algorithm

1.  Create the JSON map.
2.  Remove the `checksum` field.
3.  Encode to JSON string.
4.  Calculate SHA-256 hash of the UTF-8 bytes of the JSON string.
