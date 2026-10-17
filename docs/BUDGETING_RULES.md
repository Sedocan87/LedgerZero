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
*   **Category activity** = sum of the non-deleted transactions of
    on-budget accounts carrying the category (split lines included). Split
    parents never carry a category; a transfer leg only counts when the
    transfer crosses the budget boundary (see below).
*   **Budgeted** = money assigned to a category for a month (one row per
    category and month, id `UUIDv5("budget:<categoryId>:<yyyy-MM>")`).
*   **Available(category, M)** = budgeted up to and including M + activity up
    to the end of M. Positive balances and overspending roll over.

## On-budget and off-budget accounts

Every account is either **on budget** (the default) or **off budget**
(a tracking account: savings you don't want to budget, investments, a
loan). The "Include in budget" switch on the account form sets it
(`accounts.on_budget`, schema v19).

*   An off-budget account counts towards net worth only. Its starting
    balance and its transactions never reach To Be Budgeted, category
    activity, income or spending (reports included); a category on one of
    its transactions is ignored, and the transaction form offers none.
*   A transfer between an on-budget and an off-budget account is money
    leaving or entering the budget. Without a category its on-budget leg
    flows into TBB (a transfer to savings reduces TBB, one back from
    savings increases it). With a category (the transfer form offers one
    for exactly these transfers) the category is stored on the on-budget
    leg and the money leaves or enters that category instead: budget 500
    to "Stocks & ETFs", transfer 500 to the brokerage account with that
    category, and the category is spent while TBB is untouched. It is
    neither income nor spending.
*   Any other transfer has no category. A category left on a transfer leg
    that no longer crosses the boundary (an account was switched back) is
    ignored, so the budget stays balanced.
*   Changing the switch recalculates every month (the app asks first).

### Personal accounts (household sync)

An account can be **personal** ("Personal" switch on the account form,
`accounts.owner_id`, schema v20): it belongs to the phone's user, not to
the household. A personal account is always off budget: budgets sync, but
its money exists on one phone only, so counting it would give each phone a
different TBB. Only its name, type and balance reach the partner's phone,
where it is listed under "Your partner's accounts", read-only, and counts
towards household net worth (the account list splits net worth into
shared, mine and partner's). Its transactions stay on the owner's phone;
a transfer from a shared account into it syncs as the shared leg only
("Transfer to <name>"), and the partner cannot change or delete that leg
or book into the account. How it syncs: SYNC_ARCHITECTURE.md, "Personal
accounts".

*   An account can become personal while it has not synced yet (e.g. set
    up before pairing). Once synced, the partner's phone has its
    transactions, so it stays shared.
*   A personal account can become shared at any time (the app asks first);
    its history then syncs.
*   The first account created after onboarding is the budget's account and
    is never personal.

## To Be Budgeted (TBB)

`TBB(M) = sum of the on-budget accounts' starting balances`
`       + sum of the transactions that flow into TBB, up to the end of M`
`       - sum of everything budgeted up to and including M`

A transaction flows into TBB when it is **not deleted, uncategorised, in an
on-budget account, not a split parent, and not a transfer leg unless the
other account is off budget**. Both signs count:

*   An uncategorised inflow (salary, refund you did not categorise, the YNAB
    "Starting Balance" row) increases TBB.
*   An uncategorised outflow decreases TBB (it is spending nobody budgeted).
*   A reconciliation adjustment is an uncategorised transaction, so a
    difference found while reconciling changes TBB deliberately.
*   Starting balances are budgetable. A credit-card account opened with a
    negative starting balance (existing debt) reduces TBB by that amount.
*   Moving money between two on-budget accounts (a transfer: two linked
    rows, uncategorised) never changes TBB.
*   A split counts through its lines: lines with a category are category
    activity, lines without a category flow into TBB; the parent row itself
    never counts (it only carries the account-side total).

### Income and spending figures

*   **Income** of a period = the positive transactions that flow into TBB,
    without transfer legs.
*   **Spending** of a period = all outflows of on-budget accounts that are
    not transfer legs, with a split counted through its lines (never parent
    and lines together).
*   **Net worth** counts every account, on and off budget.

### The invariant

For every month M:

`sum over categories of Available(M) + TBB(M) = sum of the on-budget
account balances (counting transactions up to the end of M)`

This is checked by `test/domain/services/budget_invariant_test.dart` on a
real database with several accounts (including a credit card with a
negative starting balance), income, categorised and uncategorised spending,
transfers in both directions, an income split and an expense split, a
deleted row, a reconciliation adjustment and budgets in two months, and
with an off-budget account (its own rows, categorised ones included, and
transfers to and from it).

## Setting money aside

Savings and investments are kept **outside the budget**: a savings,
brokerage, crypto or retirement account is an off-budget account ("Include
in budget" off; new Savings and Investment accounts start that way, except
the first account created after onboarding). Its balance never enters TBB
and needs no budgeting, its own transactions (interest, dividends, value
changes) need no category, and it still counts towards net worth.

What the budget sees is the money moved there each month: a transfer from
a budget account to an off-budget account leaves the budget and takes a
category. The "Savings & Investments" group (Savings, Stocks & ETFs,
Crypto, Bonds, Retirement) is for these monthly contributions, so its
amounts repeat every month like any other (see BUDGET_INTERACTIONS.md,
"Filling a new month"). New budgets include the group; budgets created
earlier are offered it once on the budget screen. Budgets seeded before
"Savings" replaced "Cash Reserve" keep their Cash Reserve category.

A reserve kept inside an account you spend from cannot be off-budget
(budget membership is per account): budget it once into a category (e.g.
Savings), where it rolls over every month and stays out of TBB.

**Taking an account out of the budget** removes its balance from TBB in
every month. If that money was budgeted (e.g. a reserve in Savings), TBB
would be short by that much, so the confirmation lists the Savings &
Investments categories with money available, pre-selected, and releases
up to the account's balance from them (`BudgetingService.releaseFromCategory`:
oldest budgets first, where the money was assigned, never leaving a month
overspent and never below zero).

Interest and dividends are not categories: they are uncategorised income
and flow into TBB (or stay in an off-budget account).

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
