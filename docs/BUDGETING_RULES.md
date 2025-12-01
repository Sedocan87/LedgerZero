# Budgeting Business Rules

This document outlines the core business rules for the LedgerZero budgeting engine.

## Core Concepts

LedgerZero implements zero-based envelope budgeting. The fundamental equation is:

**Income - Budgeted = To Be Budgeted (TBB)**

Every dollar of income must be given a job (budgeted to a category).

## Terminology

*   **Income**: Transactions with a positive amount and NO category assigned. These are funds entering the budget pool.
*   **Budgeted**: Money assigned to a specific category for a specific month.
*   **Activity**: The sum of all transactions (spending) for a category in a specific month. Usually a negative number.
*   **Available**: The amount of money currently available to spend in a category.

## Calculations

### To Be Budgeted (TBB)
The amount of money available to be assigned to categories.

`TBB = Total Income (all time) - Total Budgeted (all time)`

*   **Total Income**: Sum of all transactions where `amount > 0` and `categoryId == null` up to the end of the target month.
*   **Total Budgeted**: Sum of all budget entries (`budgeted` column) across all categories up to the end of the target month.

### Category Available
The amount of money in a category "envelope".

`Available = Total Budgeted (for category, all time) + Total Activity (for category, all time)`

*   **Total Budgeted**: Sum of budget allocations for this category from the start of time up to the current month.
*   **Total Activity**: Sum of all transactions assigned to this category from the start of time up to the current month.

**Note on Rollover:**
Because the calculation sums from the "start of time", positive balances and negative overspending automatically roll over to the next month.
*   If you have \$100 available in Jan and spend \$0, you have \$100 + Feb Budgeted available in Feb.
*   If you overspend by \$50 in Jan (Available = -\$50), that negative amount reduces your available funds in Feb.

## Goals

Categories can have goals to help guide budgeting.

### Goal Types

1.  **Monthly Funding**: Budget a specific amount every month.
    *   *Target*: `targetAmount`
2.  **Target Balance**: Reach a specific available balance (eventually).
    *   *Target*: `targetAmount - currentAvailable`
3.  **Target Balance by Date**: Reach a specific available balance by a specific date.
    *   *Target*: `(targetAmount - currentAvailable) / monthsRemaining`

## Auto-Assign Rules

*   **Underfunded**: Assigns enough to meet the goal target.
*   **Average Spent**: Assigns the average spending of the last 3 months.
*   **Last Month Spent**: Assigns the amount spent last month.
*   **Last Month Budgeted**: Assigns the same amount as budgeted last month.
