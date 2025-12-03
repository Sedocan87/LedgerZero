# Payee Management Best Practices

This document outlines best practices for managing payees in LedgerZero to ensure clean data and accurate reporting.

## Naming Conventions

*   **Consistency**: Use consistent naming (e.g., "Amazon" vs "Amazon.com" vs "Amzn Mktp"). It is recommended to stick to the simple business name.
*   **Normalization**: The application performs case-insensitive filtering, but maintaining Title Case (e.g., "Starbucks") is preferred for readability.

## Managing Duplicates

Over time, you might accumulate duplicate payees (e.g., "Uber" and "Uber Eats" if you want them combined, or accidental typos).

### Merging Payees
Use the **Merge** function in the Payee Detail screen to consolidate duplicates.
1.  Navigate to the payee you want to *remove* (the "source").
2.  Select **Merge** from the menu.
3.  Choose the "target" payee (the one you want to keep).
4.  All transactions from the source payee will be reassigned to the target payee.
5.  The source payee will be permanently deleted.

**Note:** This action cannot be undone easily (requires manual database intervention), so verify your choice.

## Deletion

Deleting a payee should be done with care if they have associated transactions.

*   **With Transactions**: If you delete a payee that has transactions, the application will clear the `payee_id` from those transactions (setting it to `null`). The transactions themselves are **not** deleted, preserving your balance and history.
*   **Without Transactions**: The payee is simply removed.

## Favorites

Mark frequently used payees as **Favorites** (Star icon).
*   Favorites appear at the top of the payee list.
*   Favorites are prioritized in search results.
*   This is useful for recurring bills or frequent shopping locations.

## Exporting

You can export your payee list to CSV from the Payees screen.
*   This is useful for auditing your payee list or migrating to other tools.
*   The export includes Name, Defaults (Category/Account), Notes, and creation date.

## Optimization

*   The application automatically optimizes payee search and suggestions.
*   Frequent payees are suggested first when entering transactions.
*   The database is indexed to support fast lookups even with thousands of payees.
