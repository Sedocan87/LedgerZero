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
*   **Available(category, M)** = max(0, Available(category, M - 1))
    + budgeted in M + activity in M. A positive balance rolls over into the
    next month. A negative balance does not: the category starts the next
    month at zero. Its cash part (cash overspending) is taken out of that
    month's To Be Budgeted instead (the YNAB rule), so TBB never overstates
    the cash that can still be assigned; its credit part (credit
    overspending, card spending the category could not cover, see
    "Credit cards") is not charged, it is card debt. Within the month the
    category shows the negative amount, so it can still be covered by
    moving money before the month ends.

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

## Budget currency

*   The budget has one currency (Settings > Currency). On a fresh install
    it is proposed from the device locale (`de_DE` -> EUR, `en_US` -> USD,
    `de_CH` -> CHF; an unsupported currency falls back to USD).
*   The first on-budget account sets it: its currency field is labelled
    "Budget currency" and saving stores it in Settings.
*   Every later on-budget account is fixed to the budget currency (the form
    explains why); accounts outside the budget may use any currency, so TBB
    never sums different currencies.

## To Be Budgeted (TBB)

`TBB(M) = sum of the starting balances of the on-budget accounts that exist by M`
`         (a credit card's negative one, existing debt, counts as 0)`
`       + sum of the transactions that flow into TBB, up to the end of M`
`       - sum of everything budgeted up to and including M`
`       - sum of the cash overspending of the months before M`
`         (credit overspending is never charged)`
`       - Held(M), the money held for later months (below)`

`Held(M) = max(0, max over the months F after M, up to the last month with a budget, of`
`          sum budgeted in the months after M up to F`
`          - sum arriving in the months after M up to F)`

"Arriving" in a month means the positive transactions that flow into TBB
dated in it (income, uncategorised refunds, money moved in from an
off-budget account) plus the positive starting balances of the on-budget
accounts that start in it.

*   **Money assigned ahead is gone now, unless later money pays for it.** A
    later month's budgets are paid first from the money that arrives in the
    later months; only the part that money does not cover is taken out of
    M. Budgeting 1,000 for November while October is showing, with no
    November income, takes the 1,000 out of October's TBB (it cannot be
    assigned twice), and November's TBB does not go negative for it: the
    money was there. With 400 of November income, October gives up 600.
    And a month that budgets exactly its own income leaves every earlier
    month alone: January income 3,000 budgeted in January and February
    income 3,000 budgeted in February shows 0 in both months, however many
    months follow.
*   **Money arriving later cannot pay an earlier later month.** The maximum
    runs over the months in order: if November budgets 500 without income
    and December brings 2,000, October still holds back 500 for November
    (December's money comes too late for it).
*   **A later month's outflows and overspending stay in that month.** Only
    budgets count against M: an uncategorised outflow, a transfer to an
    off-budget account or a negative starting balance in a later month,
    and a later month's overspending, lower that month's TBB (and the ones
    after it), never an earlier month's. With no budget after M, Held(M)
    is 0.
*   **Overspending is charged to the next month.** A category that ends
    month M at -50 starts M + 1 at zero, and TBB(M + 1) is 50 lower. Each
    month's overspending is charged once; covering it in the same month
    (moving money into the category) avoids the charge.
*   **Starting balances are dated.** An account's starting balance counts
    from the month the account was created in, or from the month of its
    first transaction if that is earlier (imported or backdated history),
    so a month before the account existed shows nothing of it. There is no
    separate "opening date": the creation time (`accounts.created_at`) and
    the transactions are the record. "The month the account was created
    in" is the month on the user's calendar at that moment (the phone's
    time zone), so an account created on the evening of the 31st counts in
    that month wherever the user lives.

A transaction flows into TBB when it is **not deleted, uncategorised, in an
on-budget account, not a split parent, not a transfer leg unless the
other account is off budget, and not an outflow of a budget credit card**
(that is unfunded card debt, see "Credit cards"). Both signs count:

*   An uncategorised inflow (salary, refund you did not categorise, the YNAB
    "Starting Balance" row) increases TBB. An inflow *with* a category is a
    refund: it raises that category's available amount and never reaches
    TBB. The transaction form and quick add therefore leave an inflow
    without a category unless the user picks one (see
    [TRANSACTION_LIFECYCLE.md](TRANSACTION_LIFECYCLE.md), "Income and the
    category field").
*   An uncategorised outflow decreases TBB (it is spending nobody budgeted).
*   A reconciliation adjustment is an uncategorised transaction, so a
    difference found while reconciling changes TBB deliberately.
*   Starting balances are budgetable. A credit card's negative starting
    balance (existing debt) is not: TBB is unchanged and the card's payment
    category shows the debt as still to cover. A positive one (credit on
    the card) counts like any other.
*   Moving money between two on-budget accounts (a transfer: two linked
    rows, uncategorised) never changes TBB.
*   A split counts through its lines: lines with a category are category
    activity, lines without a category flow into TBB; the parent row itself
    never counts (it only carries the account-side total).

### Income and spending figures

*   **Income** of a period = the positive transactions that flow into TBB,
    without transfer legs.
*   **Spending** ("spent") is one figure everywhere: the home dashboard,
    Spending by Category, Category Breakdown, Spending Trends, Income vs
    Expense and Top Payees (`domain/entities/spending.dart`). It counts the
    non-deleted transactions of on-budget accounts that are not transfer
    legs, with a split counted through its lines (never parent and lines
    together):
    *   Categorised transactions net within their category and calendar
        month, both signs: a refund of 20 against 50 of groceries is 30
        spent. The result is clamped at zero, so a refund bigger than the
        month's spending in its category is no spending and never offsets
        another category or another month.
    *   Uncategorised outflows are spending (nobody budgeted them; they
        reduce TBB, or on a credit card become unfunded card debt).
        Uncategorised inflows are income, not refunds.
    *   Card spending counts once, in its category; what the card rules
        move into a payment category and payments to the card are never
        spending or income.
    *   Transfers are never spending, also not a categorised transfer to an
        off-budget account (it is neither income nor spending, see above).
    *   A period's spending is the sum of its months. Top Payees nets each
        payee's transactions per month the same way, clamped at zero.
    *   **Budget vs Actual is the exception:** "actual" is category activity
        (refunds net, clamped at zero), so a categorised transfer to an
        off-budget account counts there, because it uses up the category's
        budget. It always covers whole calendar months (the months the
        selected range touches, shown under the chart), since budgets are
        monthly.
*   **Net worth** counts every account, on and off budget, in the budget
    currency (accounts in other currencies are left out, and the report
    says which currencies; amounts in different currencies are never
    added up). A starting balance counts from the day the account exists
    (as for TBB: the earlier of its creation and its first transaction).
    The partner's personal accounts count with the balance their phone
    shared; a transfer between one of them and a shared account is inside
    the household, so it never moves net worth (the report reconstructs
    the partner's balance from the shared legs on this phone).

### The budget identity

For every month M:

```
  sum over all categories (payment categories included) of Available(M)
+ TBB(M) + Held(M)
+ CreditOverspending(M)
= Cash(M) + CardIncome(M)
```

*   **Cash(M)**: the balances of the on-budget accounts that are not budget
    credit cards (starting balance once the account exists, plus the
    transactions up to the end of M, a split counted once).
*   **CardIncome(M)**: the money that reached TBB through a budget credit
    card: its positive starting balance (once it exists) and its
    uncategorised inflows up to the end of M (rewards, a statement credit,
    an uncategorised transfer in from an off-budget account).
*   **CreditOverspending(M)**: the credit overspending the categories show
    in M (the positive amount; it resets at the end of M).

The same identity written with all on-budget balances (cards included),
where `Debt(card, M) = -balance(card, M)`:

```
  sum over ordinary categories of Available(M) + TBB(M) + Held(M)
= sum of the on-budget balances(M)
+ sum over cards of (Debt(card, M) - Available(payment category of card, M))
+ CardIncome(M) - CreditOverspending(M)
```

The middle term is the card debt not covered by its payment category:
the new part. Without credit cards the identity is the old one:
`sum of Available(M) + TBB(M) + Held(M) = sum of the on-budget balances`.

Why it holds: summing the available rule over the months gives
`Available(M) = budgeted through M + activity through M + overspending
reset before M` per category, where activity includes what the card
rules move into and out of payment categories. Adding TBB(M) cancels the
budgets through M and the cash overspending (charged to TBB); the credit
overspending reset before M stays. Each card rule keeps both sides equal:

| Event | Categories + TBB | Credit overspending | Cash + card income |
|---|---|---|---|
| Cash spending s in X | -s | 0 | -s |
| Card spending s in X, f of it funded | -s + f | +(s - f) | 0 |
| Card refund r, c of it cancelling X's credit overspending | +r - (r - c) | -c | 0 |
| Any inflow that covers credit overspending m | +m (to the payment category) | -m | 0 |
| Payment p from a cash account | -p | 0 | -p |
| Cash advance a | +a | 0 | +a |
| Balance transfer between cards | 0 | 0 | 0 |
| Uncategorised card spending | 0 | 0 | 0 |
| Uncategorised card inflow i | +i (TBB) | 0 | +i |
| End of month, credit overspending o reset | +o | -o | 0 |
| End of month, cash overspending reset | 0 (TBB pays) | 0 | 0 |

This is checked by `test/domain/services/budget_invariant_test.dart` on a
real database (helper `expectLedgerInvariant`, whose right-hand side is
raw SQL): several accounts, income, categorised and uncategorised
spending, transfers in both directions, splits, a deleted row, a
reconciliation adjustment, budgets in several months, an off-budget
account, money assigned to later months, overspent categories, and credit
cards: funded and overspent card spending, refunds, payments, existing
debt, cash advances, balance transfers, transfers between cards and
off-budget accounts, splits on a card, and eight randomised ledgers mixing
all of these over four months.

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
overspent and never below zero). The account change and the release are
saved together in one unit of work: either both happen or neither.

Interest and dividends are not categories: they are uncategorised income
and flow into TBB (or stay in an off-budget account).

## Credit cards

LedgerZero handles credit cards the way YNAB does: money for card spending
is set aside in a payment category as you spend, so you can always see
what the card will cost you and whether the money is there.

### Payment categories

*   Every **budget credit card** (account type Credit card, on budget,
    shared; a personal account is always off budget) has one payment
    category, named after the card (e.g. "Visa"), in the group "Credit
    Card Payments" ("Kreditkartenzahlungen"), listed first.
*   Its id is derived from the account id
    (`DeterministicId.cardPayment(accountId)`, the group
    `DeterministicId.cardPaymentGroup`), so both household phones create
    identical rows and no column marks it: a category is a payment
    category exactly when its id is the payment id of an account
    (`CardPayments`).
*   It is created with the card, when an account is moved onto the budget
    or changed to the credit type, and by a self-heal at start-up and
    after sync applied changes, which also renames, hides and shows it.
    The self-heal stamps what it writes with a fixed old time
    (`cardPaymentHealStamp`), so two phones healing at once write
    identical rows and every real edit wins.
*   Its name follows the card's name. While the card is open and on
    budget it cannot be deleted or moved to another group, and its group
    cannot be deleted. Closing the card, taking it off the budget or
    changing its type releases what it holds to TBB (the release flow,
    `BudgetingService.releasePaymentCategory`: budgets are given back,
    oldest first) and hides it; reopening or moving the card back shows it
    again. Deleting the card deletes it (its budgets return to TBB).
*   Transactions cannot be categorised into it (the pickers leave it out,
    `TransactionService.save` rejects it). Everything else works like any
    category: assigning, moving money, quick fills, templates, copy from
    the month before and the automatic month fill.

### What happens to the money

Category X below is the category of a card transaction. All rules run per
month, in a fixed order (date, then the time it was entered, then id), so
both phones compute the same numbers:

| Event | Category X | Payment category | TBB |
|---|---|---|---|
| Spending s on the card, X has a available | -s | +min(s, max(0, a)) | - |
| The part X could not cover | shows negative: **credit overspending** | - | - |
| Refund r on the card | +r | -(r minus what cancels X's credit overspending for this card) | - |
| Money reaching X later (a budget, a refund) while it is credit-overspent | covers it | +what was covered (oldest first) | - |
| Payment p to the card from a budget account | - | -p | - |
| Cash advance a (transfer from the card to a budget account) | - | +a | - |
| Balance transfer x from card A to card B (A pays B) | - | B: -m, A: +m, m = min(x, max(0, B's payment available)) | - |
| Uncategorised spending on the card | - | - | - (unfunded debt) |
| Uncategorised inflow on the card | - | - | +amount |
| Transfer off-budget account -> card, uncategorised | - | - | +amount |
| Transfer off-budget account -> card, with category X | like a refund | like a refund | - |
| Transfer card -> off-budget account, with category X | like card spending | like card spending | - |
| Transfer card -> off-budget account, uncategorised | - | - | - (unfunded debt) |
| Negative starting balance (existing debt) | - | - | - (shown as missing) |
| Positive starting balance | - | - | +amount |

*   **Budgets count from the first day of the month**, as in YNAB: money
    assigned to X later in the month covers card spending made earlier
    in it, and moves to the payment category.
*   **Credit overspending** (warning colour on the budget screen; cash
    overspending is in the error colour; a category with both shows the
    error colour) resets at the end of the month **without** being charged
    to the next month's TBB: it is debt the payment category does not
    cover ("still missing" on the payment row). Cash overspending keeps
    its rule (charged to the next month's TBB). A category's negative
    balance is split into its credit part (the unfunded card spending it
    still shows) and the cash part (the rest).
*   **A refund on the card** first cancels the unfunded part of that
    card's spending in X (the debt shrinks by itself), the rest is taken
    back from the payment category. A refund after the card was paid can
    leave the payment category negative (YNAB does the same): that is cash
    overspending of the payment category, charged to the next month's TBB
    unless you cover it, e.g. by moving the refund from X.
*   **Paying more than the payment category holds** makes it negative:
    cash overspending, charged to the next month's TBB (real money paid
    debt nobody budgeted). Cover old debt by assigning to the payment
    category first.
*   **Cash advance**: the cash arrives in a budget account and the payment
    category gets the same amount, earmarked to repay it (YNAB records a
    cash advance as a transfer, with the same effect).
*   **Balance transfer between two cards**: the debt moves, and so does
    the money set aside for it, at most what the paid-off card's payment
    category holds; unfunded debt stays unfunded and TBB is not touched.
*   **Uncategorised card spending** is what YNAB shows in its
    "Uncategorized" line as credit overspending: no category pays for it,
    TBB is unchanged, and the debt shows as still missing on the payment
    row. **Uncategorised card inflows** are YNAB's "Inflow: Ready to
    Assign" on a card (a reward, a statement credit): income, into TBB.
    The payment category is not reduced by it, so after such an inflow
    the payment category can hold more than the card owes (YNAB behaves
    the same); the row then shows nothing missing.
*   **A positive card balance** (credit on the card, from a positive
    starting balance or an inflow) counts in TBB; spending on the card
    still moves money to the payment category, which then holds more than
    the card owes. Move the surplus with care: the money is the card
    credit already counted in TBB.

### The payment row

The budget screen lists the "Credit Card Payments" group first. A
payment row shows Budgeted, Activity (spending moved in, minus refunds
moved back and payments) and Available, and under the name what is still
missing to pay the card in full: `max(0, -card balance at the end of the
month - Available)`. Its quick actions add **Cover the card balance**
(assign what is missing); the spending-based fills (last month's
spending, average spent) are not offered for it, because nothing is
spent from a payment category. Budget previous month, zero out and move
money are. The account screen of a card shows the same two
figures.

### Reports

Payments to the card are transfers, and moves into payment categories are
not transactions: neither is spending or income in any report. Card
spending counts as spending of its category (once), like any other.

## Deleting things

*   Deleting a category moves its budgets (merged per month) and all of its
    transactions to the category you pick, so TBB does not change. Deleting
    it without a replacement removes its budgets (the money returns to TBB)
    and leaves its transactions uncategorised (they then count towards TBB).
*   Deleting an account deletes its transactions; the other leg of each
    transfer stays in the other account as a normal uncategorised
    transaction (and therefore counts towards TBB). A credit card's
    payment category is deleted with it (its budgets return to TBB).
    Closing an account keeps everything and is usually what you want.
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
    of the last 3 months, averaged over the months that had any activity
    (a category that is one month old is not divided by three).

Each records an undo action. The service also has `underfunded` (assign
what the goal still needs); it is not offered in the app because goals
cannot be set yet.
