YNAB Export Format Specification

The YNAB (You Need A Budget) web application ("nYNAB") provides an export feature that produces a ZIP file containing two CSV files:
1.  `[Budget Name] as of [Date] - Budget.csv`
2.  `[Budget Name] as of [Date] - Register.csv`

### 1. Register.csv (Transactions)

This file contains the transaction history for all accounts (or selected ones).

**Standard Columns:**
*   `Account`: Name of the account (e.g., "Checking", "Citi Visa").
*   `Flag`: Color flag (e.g., "Red", "Blue", or empty).
*   `Date`: Transaction date (format varies by locale, commonly YYYY-MM-DD or MM/DD/YYYY).
*   `Payee`: Name of the payee.
    *   For transfers: `Transfer : [Account Name]`
*   `Category Group`: The master category group name.
    *   For transfers: empty or `Payment`?
    *   For splits: `Split (Multiple Categories)`?
*   `Category`: The sub-category name.
    *   For splits: `Split (Multiple Categories)` on the parent row?
*   `Memo`: Notes.
    *   For splits: Often contains the split details if not expanded, or separate rows.
*   `Outflow`: Amount leaving the budget (positive number).
*   `Inflow`: Amount entering the budget (positive number).
*   `Cleared`: Status (`C` for cleared, `U` for uncleared, `R` for reconciled).

**Split Transactions:**
*   **Parent Row**:
    *   `Payee`: The actual payee.
    *   `Category Group`: `Inflow: To be Budgeted` (if income) or empty? Or just `Split`.
    *   `Category`: `Split (Multiple Categories)`.
    *   `Memo`: Total amount details or user memo.
    *   `Outflow`/`Inflow`: Total amount.
*   **Child Rows** (Sub-transactions):
    *   Often NOT included in the main export in some versions, OR included as separate rows.
    *   *Wait*: YNAB's export behavior for splits is tricky.
    *   According to user reports: YNAB exports split transactions as *separate rows* for each split part, PLUS a row for the parent? Or just the split parts?
    *   Actually, YNAB export typically "flattens" splits into individual rows, but keeping the same Payee and Date. But how do we know they belong together?
    *   *Correction*: In the official export:
        *   Splits are exported as *multiple rows*.
        *   There is NO unique ID linking them in the CSV.
        *   However, they share: `Account`, `Date`, `Payee`.
        *   The `Memo` might differ (`(Split 1/3) ...`?).
        *   Actually, YNAB does *not* export the parent row in the Register export usually; it exports the splits as individual transactions.
        *   *Wait, this is critical.* If it exports splits as individual transactions, they look like separate transactions. But they are part of one "event".
        *   Let's check if there's a parent row. Some sources say YNAB exports the parent row with `Split (Multiple Categories)` in the Category column, and then *also* the sub-rows? No, that would double-count.
        *   Most likely: It exports *only* the split parts (sub-transactions).
        *   *Issue*: If I import them as separate transactions, they lose their "split" nature (i.e. one bank transaction).
        *   *Resolution*: For MVP import, importing them as separate transactions is acceptable, though not ideal. However, if I can detect they are splits (e.g. same Account, Date, Payee, and consecutive), I might merge them. But YNAB allows same-day same-payee separate transactions.
        *   *Actually*: YNAB export *does* include a "Memo" which might help.
        *   Let's assume for now we treat them as individual transactions unless we find a clear "Split" marker.
        *   *Wait*: If YNAB exports them as individual rows with their respective categories, they are functionally correct for budgeting. The only loss is the "link" that they were one swipe.

### 2. Budget.csv (Allocations)

This file contains the monthly budget values.

**Standard Columns:**
*   `Month`: The budget month (e.g., "Jan 2023", "01/01/2023").
*   `Category Group`: Master category.
*   `Category`: Sub-category.
*   `Budgeted`: Amount assigned.
*   `Activity`: Amount spent (calculated).
*   `Available`: Remaining (calculated).

**Parsing Logic:**
*   Iterate through rows.
*   Find or create Category Group.
*   Find or create Category.
*   Parse Month.
*   Create `Budget` entry in `Budgets` table for that `(Category, Month)`.
*   Set `budgeted` amount.
*   Ignore `Activity` and `Available` as they are re-calculated by LedgerZero based on imported transactions.

### 3. YNAB4 (.ynab4) Format (Legacy)

*   This is a directory bundle.
*   Data is in JSON format.
*   `Budget.ymeta`: Version info.
*   `data/Budget.yfull`: Full budget data (Accounts, Payees, Transactions, Subtransactions, MasterCategories, SubCategories, MonthlyBudgets).
*   This is much richer and allows perfect reconstruction (including splits).

**Plan:**
1.  Prioritize **CSV Export** (nYNAB) as it's the current standard.
2.  YNAB4 support is Task 533.
