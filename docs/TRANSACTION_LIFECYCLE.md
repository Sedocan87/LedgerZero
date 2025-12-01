# Transaction Lifecycle

This document describes the lifecycle and states of a transaction in LedgerZero.

## Overview

A transaction represents a movement of funds. It progresses through various states of verification (clearing/reconciliation) and can be linked to other transactions (transfers, splits).

## States

### 1. Creation
When a transaction is created, it is persisted in the database with `createdAt` timestamp.
- **Default Status**: `uncleared`
- **Default Approval**: `true` (unless created by sync/import rules which might set it to false)
- **Deleted**: `false`

### 2. Approval Status (`approved` boolean)
- **Unapproved (`false`)**: Newly imported transactions or match candidates often start as unapproved, requiring user review.
- **Approved (`true`)**: The user has verified the transaction details.

### 3. Clearing Status (`cleared` enum)
Reflects the transaction's status with the bank.
- **Uncleared (0)**: Transaction recorded but not yet posted by the bank.
- **Cleared (1)**: Transaction has posted to the bank account.
- **Reconciled (2)**: Transaction has been verified against a bank statement and locked.
  - Reconciled transactions should generally not be modified.

### 4. Deletion (`isDeleted` boolean)
LedgerZero uses **Soft Deletion**.
- **Active (`false`)**: Normal state.
- **Deleted (`true`)**: Hidden from UI but retained in database for sync consistency and recovery.
  - Sync mechanism propagates deletion status.
  - Undo/Redo can restore soft-deleted transactions.

## Linked Transactions

### Transfers
A transfer moves money between two accounts. It consists of two linked transactions.
- **Source Transaction**: Outflow from Account A.
  - `transferAccountId`: Account B
  - `transferTransactionId`: ID of Destination Transaction
- **Destination Transaction**: Inflow to Account B.
  - `transferAccountId`: Account A
  - `transferTransactionId`: ID of Source Transaction

**Lifecycle Rules**:
- Creating a transfer creates both transactions atomically.
- Deleting one side deletes the other (cascade).
- Editing amount/date on one side updates the other.

### Split Transactions
A single transaction split into multiple categories.
- **Parent Transaction**: Holds the total amount and main details.
  - `amount`: Total sum
  - `categoryId`: NULL (usually)
- **Child Transactions**: Represents the splits.
  - `parentTransactionId`: ID of Parent Transaction
  - `amount`: Partial amount
  - `categoryId`: Specific category
  - `accountId`: Same as Parent
  - `date`: Same as Parent

**Lifecycle Rules**:
- Sum of children amounts MUST equal parent amount.
- Deleting parent deletes all children.
- Children are usually hidden in main lists, shown only when expanding parent.

## Undo/Redo

Operations in `TransactionService` are reversible.
- **Actions**: Create, Update, Delete (Single & Batch), Transfer, Split.
- **Mechanism**: `UndoService` maintains a stack of `ReversibleAction`s.
- **Scope**: Session-based (cleared on app restart).

## Batch Operations

To optimize performance, operations on multiple transactions are batched.
- **Bulk Approve/Reject**: Updates `approved` status.
- **Bulk Reconcile**: Sets `cleared` to `Reconciled`.
- **Bulk Delete**: Soft deletes multiple transactions in one query.
