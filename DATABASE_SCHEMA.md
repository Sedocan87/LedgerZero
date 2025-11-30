# Database Schema

This document outlines the database schema for LedgerZero, implemented using [Drift](https://drift.simonbinder.eu/) (SQLite).

## Tables

### **accounts**
Stores financial accounts (checking, savings, credit cards, etc.).

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **name** (`TEXT`, NOT NULL) - User-defined name of the account.
- **type** (`TEXT`, NOT NULL) - Type of account (e.g., 'checking', 'savings', 'credit', 'cash').
- **currency** (`TEXT`, DEFAULT 'USD') - ISO 4217 currency code.
- **starting_balance** (`REAL`, DEFAULT 0.0) - Balance at the time of account creation.
- **current_balance** (`REAL`, DEFAULT 0.0) - Current calculated balance.
- **is_closed** (`INTEGER`, DEFAULT 0) - Boolean flag (0=active, 1=closed).
- **created_at** (`TEXT`) - Timestamp of creation (ISO 8601).
- **updated_at** (`TEXT`) - Timestamp of last update (ISO 8601).

### **category_groups**
Groups categories for organization (e.g., "Monthly Bills", "Daily Living").

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **name** (`TEXT`, NOT NULL) - User-defined name of the group.
- **sort_order** (`INTEGER`) - Value for ordering groups in the UI.
- **created_at** (`TEXT`) - Timestamp of creation.

### **categories**
Individual budget categories.

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **name** (`TEXT`, NOT NULL) - User-defined name of the category.
- **category_group_id** (`TEXT`, FOREIGN KEY) - References `category_groups.id`.
- **is_hidden** (`INTEGER`, DEFAULT 0) - Boolean flag (0=visible, 1=hidden).
- **sort_order** (`INTEGER`) - Value for ordering categories within a group.
- **created_at** (`TEXT`) - Timestamp of creation.

### **payees**
Entities to whom money is paid or from whom money is received.

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **name** (`TEXT`, NOT NULL) - Name of the payee.
- **auto_category_id** (`TEXT`, FOREIGN KEY) - Default category for this payee (References `categories.id`).
- **created_at** (`TEXT`) - Timestamp of creation.

### **transactions**
Records of financial activity.

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **account_id** (`TEXT`, FOREIGN KEY, NOT NULL) - References `accounts.id`.
- **date** (`TEXT`, NOT NULL) - Date of the transaction (ISO 8601).
- **amount** (`REAL`, NOT NULL) - Transaction amount (negative for outflows, positive for inflows).
- **payee_id** (`TEXT`, FOREIGN KEY) - References `payees.id`.
- **category_id** (`TEXT`, FOREIGN KEY) - References `categories.id`.
- **memo** (`TEXT`) - Optional note or description.
- **cleared** (`INTEGER`, DEFAULT 0) - Status: 0=uncleared, 1=cleared, 2=reconciled.
- **approved** (`INTEGER`, DEFAULT 1) - Boolean flag (0=needs approval, 1=approved).
- **transfer_account_id** (`TEXT`, FOREIGN KEY) - For transfers, references the other `accounts.id`.
- **transfer_transaction_id** (`TEXT`) - Link to the counterpart transaction in a transfer.
- **created_at** (`TEXT`) - Timestamp of creation.
- **updated_at** (`TEXT`) - Timestamp of last update.

### **budgets**
Monthly budget allocations for categories.

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **category_id** (`TEXT`, FOREIGN KEY, NOT NULL) - References `categories.id`.
- **month** (`TEXT`, NOT NULL) - Budget month (Format: YYYY-MM).
- **budgeted** (`REAL`, DEFAULT 0.0) - Amount assigned to this category for the month.
- **activity** (`REAL`, DEFAULT 0.0) - Sum of transactions for this category in the month.
- **available** (`REAL`, DEFAULT 0.0) - Calculated available amount (budgeted - activity + carry-over).
- **created_at** (`TEXT`) - Timestamp of creation.
- **updated_at** (`TEXT`) - Timestamp of last update.
- **UNIQUE constraint**: `(category_id, month)`

### **scheduled_transactions**
Recurring or future one-time transactions.

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **account_id** (`TEXT`, FOREIGN KEY) - References `accounts.id`.
- **payee_id** (`TEXT`, FOREIGN KEY) - References `payees.id`.
- **category_id** (`TEXT`, FOREIGN KEY) - References `categories.id`.
- **amount** (`REAL`) - Transaction amount.
- **frequency** (`TEXT`) - Recurrence rule (e.g., 'daily', 'weekly', 'monthly', 'yearly').
- **next_date** (`TEXT`) - The next occurrence date.
- **end_date** (`TEXT`) - Optional end date for the recurrence.
- **auto_approve** (`INTEGER`, DEFAULT 0) - Boolean flag (0=manual entry, 1=auto-enter).
- **created_at** (`TEXT`) - Timestamp of creation.

### **sync_log**
Log of changes for synchronization (Conflict-Free Replicated Data Type - CRDT style).

- **id** (`TEXT`, PRIMARY KEY) - Unique identifier (UUID).
- **delta_filename** (`TEXT`, UNIQUE) - Name of the delta file.
- **action** (`TEXT`) - Type of change ('INSERT', 'UPDATE', 'DELETE').
- **table_name** (`TEXT`) - The table affected (mapped from `targetTableName`).
- **record_id** (`TEXT`) - ID of the record affected.
- **applied_at** (`TEXT`) - Timestamp when the change was applied.
- **device_uuid** (`TEXT`) - ID of the device that originated the change.

## Indexes

To optimize query performance, the following indexes are defined:

```sql
-- Transactions are frequently queried by account, date, and category
CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_date ON transactions(date);
CREATE INDEX idx_transactions_category ON transactions(category_id);

-- Budgets are frequently queried by month
CREATE INDEX idx_budgets_month ON budgets(month);

-- Sync logs are ordered by application time
CREATE INDEX idx_sync_log_applied ON sync_log(applied_at);
```
