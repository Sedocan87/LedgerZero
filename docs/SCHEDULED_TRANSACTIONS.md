# Scheduled Transactions

LedgerZero supports scheduled transactions to automate recurring expenses and income.

## Recurrence Rules

Scheduled transactions can be configured with the following recurrence frequencies:
- **Daily**: Repeats every N days.
- **Weekly**: Repeats every N weeks.
- **Monthly**: Repeats every N months.
- **Yearly**: Repeats every N years.

The `interval` field determines the N value (e.g., every 2 weeks).

## Month-End Handling

When scheduling monthly transactions, the system handles month-end overflows intelligently:
- If a transaction is scheduled for the 31st, and the next month only has 30 days (or 28/29 for February), the system automatically adjusts the date to the last day of that month.
- Example: Jan 31 + 1 month -> Feb 28 (or 29).

## Processing Logic

The `ScheduledTransactionService` runs periodically (typically on app startup) to process due transactions.

### Catch-Up Logic
If the application is not opened for a period of time, the service "catches up" on all missed occurrences.
- It calculates every occurrence date from the last processed date up to the current date.
- It creates a real transaction for each missed occurrence.
- This ensures that account balances remain accurate even if the app wasn't used for months.

### Optimization
To ensure performance, the service:
1. Queries only transactions that are due (on or before today).
2. Calculates all necessary catch-up transactions in memory.
3. Inserts all new transactions in a single batch operation.
4. Updates the scheduled transaction record only once with the final state (next future date).

## Auto-Approval

Scheduled transactions have an `autoApprove` flag.
- **True**: Created transactions are marked as `approved: true`. They immediately affect the budget and account balance.
- **False**: Created transactions are marked as `approved: false`. They appear in the transaction list but require user review before fully affecting the budget (depending on configuration, though typically unapproved transactions still affect balance but are flagged).

## Notifications

The system schedules a local notification to alert the user 1 day before a scheduled transaction is due (at 9:00 AM).
- If the next occurrence is in the future, a notification is scheduled.
- If the schedule is finished, any pending notification is cancelled.

## Database Schema

`scheduled_transactions` table:
- `id`: Unique identifier.
- `account_id`, `payee_id`, `category_id`: Foreign keys.
- `amount`: Transaction amount.
- `frequency`: Enum (daily, weekly, monthly, yearly).
- `interval`: Integer.
- `next_date`: The date of the next occurrence.
- `end_date`: Optional end date.
- `occurrence_count`: Optional number of remaining occurrences.
- `auto_approve`: Boolean.
