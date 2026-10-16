# Budgeting Business Rules

This document outlines the core business rules for the LedgerZero budgeting engine.

## Core Concepts

LedgerZero implements zero-based envelope budgeting: every unit of money in
your accounts is either assigned to a category ("available") or waiting to be
assigned ("To Be Budgeted", TBB). All amounts are integer minor units
(hundredths); all dates are calendar days, stored as UTC midnight of the
day.

## Building blocks

*   **Account balance** = starting balance + sum of the account's non-deleted
    transactions that are not split lines (a split counts once, through its
    parent row).
*   **Category activity** = sum of the non-deleted transactions carrying the
    category (split lines included). Transfer legs and split parents never
    carry a category.
*   **Budgeted** = money assigned to a category for a month (one row per
    category and month, id `UUIDv5("budget:<categoryId>:<yyyy-MM>")`).
*   **Available(category, M)** = budgeted up to and including M + activity up
    to the end of M. Positive balances and overspending roll over.

## To Be Budgeted (TBB)

`TBB(M) = sum of all accounts' starting balances`
`       + sum of the transactions that flow into TBB, up to the end of M`
`       - sum of everything budgeted up to and including M`

A transaction flows into TBB when it is **not deleted, uncategorised, not a
transfer leg and not a split parent**. Both signs count:

*   An uncategorised inflow (salary, refund you did not categorise, the YNAB
    "Starting Balance" row) increases TBB.
*   An uncategorised outflow decreases TBB (it is spending nobody budgeted).
*   A reconciliation adjustment is an uncategorised transaction, so a
    difference found while reconciling changes TBB deliberately.
*   Starting balances are budgetable. A credit-card account opened with a
    negative starting balance (existing debt) reduces TBB by that amount.
*   Moving money between your accounts (a transfer: two linked rows,
    uncategorised) never changes TBB.
*   A split counts through its lines: lines with a category are category
    activity, lines without a category flow into TBB; the parent row itself
    never counts (it only carries the account-side total).

### Income and spending figures

*   **Income** of a period = the positive transactions that flow into TBB.
*   **Spending** of a period = all outflows that are not transfer legs, with a
    split counted through its lines (never parent and lines together).

### The invariant

For every month M:

`sum over categories of Available(M) + TBB(M) = sum of account balances
(counting transactions up to the end of M)`

This is checked by `test/domain/services/budget_invariant_test.dart` on a
real database with several accounts (including a credit card with a
negative starting balance), income, categorised and uncategorised spending,
transfers in both directions, an income split and an expense split, a
deleted row, a reconciliation adjustment and budgets in two months.

## Credit cards (current behaviour)

There are no credit-card payment categories yet. Today a credit card is an
ordinary budget account:

*   Spending on the card with a category reduces that category's available
    amount and the card balance (it becomes more negative), exactly like
    spending from checking. The money for it stays "in" the category, not
    in a payment envelope.
*   Paying the card from checking is a transfer: both balances change, TBB
    and categories do not.
*   Existing card debt entered as a negative starting balance reduces TBB
    immediately (you have to "cover" it from TBB).
*   Uncategorised card spending reduces TBB like any uncategorised outflow.

So the budget always balances, but it does not show how much of the money in
your categories is earmarked for paying the card.

## Deleting things

*   Deleting a category moves its budgets (merged per month) and all of its
    transactions to the category you pick, so TBB does not change. Deleting
    it without a replacement removes its budgets (the money returns to TBB)
    and leaves its transactions uncategorised (they then count towards TBB).
*   Deleting an account deletes its transactions; the other leg of each
    transfer stays in the other account as a normal uncategorised
    transaction (and therefore counts towards TBB). Closing an account keeps
    everything and is usually what you want.
*   Deleting one line of a split deletes the whole split (otherwise the
    lines would no longer add up to the account-side amount).

## Goals (not available yet)

Goals cannot be set in the app yet: there is no goals UI (planned, see
ROADMAP.md), the category form has no goal fields and imports do not bring
goals in. The data model and the calculations below exist for that future
feature and are covered by tests only.

### Goal Types (planned)

1.  **Monthly Funding**: Budget a specific amount every month.
    *   *Target*: `targetAmount`
2.  **Target Balance**: Reach a specific available balance (eventually).
    *   *Target*: `targetAmount - currentAvailable`
3.  **Target Balance by Date**: Reach a specific available balance by a specific date.
    *   *Target*: `(targetAmount - currentAvailable) / monthsRemaining`

## Auto-Assign Rules

Offered in the budget row's quick actions (long-press a category):

*   **Budget Previous Month** (`lastMonthBudgeted`): assigns the same amount
    as budgeted last month.
*   **Budget Last Month's Spending** (`lastMonthSpent`): assigns the amount
    spent last month.
*   **Budget Average Spent** (`averageSpent`): assigns the average spending
    of the last 3 months.

Each records an undo action. The service also has `underfunded` (assign
what the goal still needs); it is not offered in the app because goals
cannot be set yet.
