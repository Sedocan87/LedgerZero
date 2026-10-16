# Database Schema

LedgerZero stores everything in one [Drift](https://drift.simonbinder.eu/)
database (SQLite built as SQLCipher, encrypted with a random data key; see
[docs/ENCRYPTION.md](docs/ENCRYPTION.md)). Tables are defined in
`lib/data/database/tables/`, the database and its migrations in
`lib/data/database/database.dart`.

**Current schema version: 18.** The tables below are generated from the
exported schema `drift_schemas/drift_schema_v18.json`, which the migration
tests (`test/database/migration_test.dart`) compare against the code.

## Version history (recent)

| Version | Change |
|---|---|
| 15 | Money columns REAL -> INTEGER minor units (`CAST(ROUND(x * 100) AS INTEGER)`), budget template JSON and rule amount conditions converted; `accounts.current_balance`, `budgets.activity`, `budgets.available` dropped; nullable `updated_at` on every synced table; local dates rewritten as UTC. |
| 16 | `scheduled_transactions.memo` and `scheduled_transactions.anchor_day`. |
| 17 | Sync format v2 bookkeeping tables (`sync_*`), `pending_sync_changes.old_updated_at`; the v1 `sync_log` table was dropped. |
| 18 | The unused quick-add keyword table `parsing_rules` (never synced, never written by the app) was dropped (`DROP TABLE IF EXISTS`). Upgrades from v11 or older no longer create it in the v12 step. |

## Conventions

- **Money** is `INTEGER` minor units: hundredths of the currency unit for
  every currency (`1250` = 12.50; JPY is stored x100 too and displayed
  without decimals).
- **Derived values are never stored**: account balance =
  `starting_balance + SUM(amount)` of the account's non-deleted rows that are
  not split children; category activity, available and To Be Budgeted are
  computed (see [docs/BUDGETING_RULES.md](docs/BUDGETING_RULES.md)).
- **Date/times** are UTC ISO-8601 text (`build.yaml`:
  `store_date_time_values_as_text`). Date-only values (`transactions.date`,
  `scheduled_transactions.next_date`/`end_date`, `categories.target_date`)
  are UTC midnight of the calendar day the user picked.
- **Booleans** are `INTEGER` 0/1 with a `CHECK` constraint (shown as `bool`).
- **Ids** are UUID strings; some are deterministic UUIDv5 values
  (`lib/core/constants/deterministic_id.dart`) so that two devices create the
  same row: budget rows, seeded default groups/categories and scheduled
  occurrences.
- **Synced tables** (`AppDatabase.syncedTables`): accounts, categories,
  category_groups, transactions, payees, budgets, scheduled_transactions,
  budget_templates, report_notes, import_profiles, rules. Each has a nullable
  `updated_at` (the conflict timestamp) and AFTER INSERT/UPDATE/DELETE
  triggers (`<table>_insert_trigger`, `<table>_update_trigger`,
  `<table>_delete_trigger`) that record the change in `pending_sync_changes`
  and fill in `updated_at` when a write left it unset or unchanged. The
  triggers do nothing while `sync_applying` holds a row. See
  [docs/SYNC_ARCHITECTURE.md](docs/SYNC_ARCHITECTURE.md).

## Tables

### `accounts`

Financial accounts. Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `name` | TEXT | NOT NULL |  |
| `type` | TEXT | NOT NULL | `checking`, `savings`, `credit`, `cash`, ... |
| `currency` | TEXT | NOT NULL DEFAULT 'USD' | ISO 4217 code. |
| `starting_balance` | INTEGER | NOT NULL DEFAULT 0 | Opening balance (minor units). The current balance is computed, never stored. |
| `is_closed` | INTEGER | NOT NULL DEFAULT 0 bool |  |
| `color` | INTEGER | NULL | ARGB colour. |
| `icon` | TEXT | NULL |  |
| `notes` | TEXT | NULL |  |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `category_groups`

Groups of categories ("Bills", "Everyday", ...). Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `name` | TEXT | NOT NULL |  |
| `sort_order` | INTEGER | NULL |  |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `categories`

Budget categories (envelopes). Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `name` | TEXT | NOT NULL |  |
| `category_group_id` | TEXT | NULL REFERENCES category_groups (id) |  |
| `is_hidden` | INTEGER | NOT NULL DEFAULT 0 bool |  |
| `sort_order` | INTEGER | NULL |  |
| `goal_type` | TEXT | NULL | `targetBalance`, `targetBalanceByDate`, `monthlyFunding` or NULL. |
| `target_amount` | INTEGER | NULL | Goal amount (minor units). |
| `target_date` | TEXT | NULL | Goal date (UTC midnight). |
| `color` | INTEGER | NULL |  |
| `icon` | TEXT | NULL |  |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `budgets`

Amount assigned to a category in a month. Row id = UUIDv5 of `budget:<categoryId>:<yyyy-MM>`. Activity and available are computed from transactions. Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `category_id` | TEXT | NOT NULL REFERENCES categories (id) |  |
| `month` | TEXT | NOT NULL | `YYYY-MM`. |
| `budgeted` | INTEGER | NOT NULL DEFAULT 0 | Minor units. |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`; `UNIQUE (category_id, month)`

### `budget_templates`

Saved sets of budget amounts. Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `name` | TEXT | NOT NULL |  |
| `data` | TEXT | NOT NULL | JSON object `categoryId -> budgeted` (minor units). |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `payees`

Payees, with optional default category and account. Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `name` | TEXT | NOT NULL |  |
| `auto_category_id` | TEXT | NULL REFERENCES categories (id) |  |
| `default_account_id` | TEXT | NULL REFERENCES accounts (id) |  |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |
| `icon` | TEXT | NULL |  |
| `color` | INTEGER | NULL |  |
| `notes` | TEXT | NULL |  |
| `is_favorite` | INTEGER | NOT NULL DEFAULT 0 bool |  |

Table constraints: `PRIMARY KEY (id)`

### `transactions`

Ledger rows. Split parents carry no category; their children (`parent_transaction_id`) do. A transfer is two rows linked both ways by `transfer_transaction_id`. Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `account_id` | TEXT | NOT NULL REFERENCES accounts (id) |  |
| `date` | TEXT | NOT NULL | UTC midnight of the calendar day. |
| `amount` | INTEGER | NOT NULL | Minor units; negative = outflow. |
| `payee_id` | TEXT | NULL REFERENCES payees (id) |  |
| `category_id` | TEXT | NULL REFERENCES categories (id) |  |
| `memo` | TEXT | NULL |  |
| `cleared` | INTEGER | NOT NULL DEFAULT 0 | 0 = uncleared, 1 = cleared, 2 = reconciled. |
| `approved` | INTEGER | NOT NULL DEFAULT 1 bool |  |
| `is_deleted` | INTEGER | NOT NULL DEFAULT 0 bool | Soft delete (kept for undo and sync). |
| `transfer_account_id` | TEXT | NULL REFERENCES accounts (id) | The other account of a transfer. |
| `transfer_transaction_id` | TEXT | NULL | The counterpart leg of a transfer. |
| `parent_transaction_id` | TEXT | NULL REFERENCES transactions (id) | Set on split children. |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `report_notes`

One free-text note per report month. Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `date` | TEXT | NOT NULL | `YYYY-MM`. |
| `note` | TEXT | NOT NULL |  |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`; `UNIQUE (date)`

### `scheduled_transactions`

Recurring or future transactions. Generated occurrences get id UUIDv5 of `scheduled:<id>:<yyyy-MM-dd>`. Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `account_id` | TEXT | NULL REFERENCES accounts (id) |  |
| `payee_id` | TEXT | NULL REFERENCES payees (id) |  |
| `category_id` | TEXT | NULL REFERENCES categories (id) |  |
| `amount` | INTEGER | NULL | Minor units; negative = outflow. |
| `frequency` | TEXT | NULL | `daily`, `weekly`, `monthly`, `yearly`. |
| `interval` | INTEGER | NULL | Every N periods. |
| `occurrence_count` | INTEGER | NULL | Stop after N occurrences. |
| `next_date` | TEXT | NULL | UTC midnight. |
| `end_date` | TEXT | NULL | UTC midnight. |
| `auto_approve` | INTEGER | NOT NULL DEFAULT 0 bool |  |
| `memo` | TEXT | NULL | Copied to generated transactions (v16). |
| `anchor_day` | INTEGER | NULL | Day of month (1-31) monthly/yearly schedules aim for (v16); NULL = day of `next_date`. |
| `created_at` | TEXT | NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `pending_sync_changes`

Local changes captured by the sync triggers; turned into an encrypted change file and then deleted. Local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | INTEGER | NOT NULL PRIMARY KEY AUTOINCREMENT |  |
| `table_name` | TEXT | NOT NULL | Synced table. |
| `record_id` | TEXT | NOT NULL |  |
| `action` | TEXT | NOT NULL | `INSERT`, `UPDATE`, `DELETE`. |
| `changed_at` | TEXT | NOT NULL DEFAULT (CURRENT_TIMESTAMP) |  |
| `old_updated_at` | TEXT | NULL | DELETE only: the deleted row's `updated_at` (v17). |

### `parsing_history`

Natural-language entries the user confirmed (local learning, not synced). Local only. Quick Add uses the most recent entry for an input (`ORDER BY created_at DESC, id DESC`).

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `input` | TEXT | NOT NULL |  |
| `payee_id` | TEXT | NULL |  |
| `category_id` | TEXT | NULL |  |
| `created_at` | TEXT | NOT NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `import_profiles`

Saved CSV import settings (column mapping, date format, decimal separator, sign). Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `name` | TEXT | NOT NULL |  |
| `date_format` | TEXT | NOT NULL |  |
| `decimal_separator` | TEXT | NOT NULL |  |
| `outflow_is_negative` | INTEGER | NOT NULL bool |  |
| `date_column` | TEXT | NULL |  |
| `amount_column` | TEXT | NULL |  |
| `payee_column` | TEXT | NULL |  |
| `memo_column` | TEXT | NULL |  |
| `category_column` | TEXT | NULL |  |
| `created_at` | TEXT | NOT NULL |  |
| `updated_at` | TEXT | NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `rules`

Transaction rules (conditions -> actions). Synced.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | TEXT | NOT NULL |  |
| `name` | TEXT | NOT NULL |  |
| `description` | TEXT | NULL |  |
| `priority` | INTEGER | NOT NULL |  |
| `is_active` | INTEGER | NOT NULL DEFAULT 1 bool |  |
| `match_logic` | TEXT | NOT NULL | `and` (all conditions) or `or` (any). |
| `conditions` | TEXT | NOT NULL | JSON list; amount conditions in minor units. |
| `actions` | TEXT | NOT NULL | JSON list. |
| `created_at` | TEXT | NOT NULL |  |
| `updated_at` | TEXT | NOT NULL |  |

Table constraints: `PRIMARY KEY (id)`

### `sync_device_progress`

Per remote device: highest change-file sequence applied here. Local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `device_id` | TEXT | NOT NULL |  |
| `last_sequence` | INTEGER | NOT NULL DEFAULT 0 |  |

Table constraints: `PRIMARY KEY (device_id)`

### `sync_kv`

Sync state that must live in the encrypted database (`sync_key`, `sync_id`, `own_sequence`, `full_upload_required`, `own_snapshots`, `snapshot_clock_started`). Local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `key` | TEXT | NOT NULL |  |
| `value` | TEXT | NOT NULL |  |

Table constraints: `PRIMARY KEY (key)`

### `sync_row_versions`

Known version of every synced row (conflict timestamp, writing device, tombstone). Tombstones are pruned after 180 days. Local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `sync_table` | TEXT | NOT NULL |  |
| `row_id` | TEXT | NOT NULL |  |
| `version` | INTEGER | NOT NULL | `updated_at` in microseconds since the epoch, UTC. |
| `device_id` | TEXT | NOT NULL |  |
| `deleted` | INTEGER | NOT NULL DEFAULT 0 bool | Tombstone. |
| `sequence` | INTEGER | NULL | Own change file that carried this version. |

Table constraints: `PRIMARY KEY (sync_table, row_id)`

### `sync_conflicts`

Local edits that lost against a newer remote edit; shown in Sync settings. Local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | INTEGER | NOT NULL PRIMARY KEY AUTOINCREMENT |  |
| `sync_table` | TEXT | NOT NULL |  |
| `row_id` | TEXT | NOT NULL |  |
| `local_snapshot` | TEXT | NULL | JSON of the overwritten local row; NULL = it was a delete. |
| `remote_snapshot` | TEXT | NULL | JSON of the winning row; NULL = remote delete. |
| `remote_device_id` | TEXT | NOT NULL |  |
| `resolved_at` | TEXT | NOT NULL |  |

### `sync_quarantine`

Change files that could not be applied (or come from a newer schema); block only their own device's later files. Local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `filename` | TEXT | NOT NULL |  |
| `device_id` | TEXT | NOT NULL |  |
| `sequence` | INTEGER | NOT NULL |  |
| `reason` | TEXT | NOT NULL | `failed` or `newer_schema`. |
| `error` | TEXT | NOT NULL |  |
| `attempts` | INTEGER | NOT NULL DEFAULT 1 |  |
| `first_seen` | TEXT | NOT NULL |  |
| `last_attempt` | TEXT | NOT NULL |  |
| `next_attempt` | TEXT | NOT NULL |  |

Table constraints: `PRIMARY KEY (filename)`

### `sync_applying`

Holds one row while a change file is applied; the sync triggers skip writes while it is set. Local only.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | INTEGER | NOT NULL |  |

Table constraints: `PRIMARY KEY (id)`

## Indexes

```sql
CREATE INDEX idx_budgets_month ON budgets (month);
CREATE INDEX idx_transactions_account ON transactions (account_id);
CREATE INDEX idx_transactions_date ON transactions (date);
CREATE INDEX idx_transactions_category ON transactions (category_id);
CREATE INDEX idx_transactions_payee ON transactions (payee_id);
CREATE INDEX idx_payees_name ON payees (name);
CREATE INDEX idx_payees_is_favorite ON payees (is_favorite);
CREATE INDEX idx_pending_sync_record ON pending_sync_changes (table_name, record_id);
CREATE INDEX idx_sync_row_versions_deleted ON sync_row_versions (deleted, version);
```
