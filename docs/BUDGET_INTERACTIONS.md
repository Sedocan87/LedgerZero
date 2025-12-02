# Budget Interaction Patterns

This document outlines the interaction patterns and data flow for the Budget Screen in LedgerZero.

## Core Concepts

*   **TBB (To Be Budgeted):** The pool of money available to be assigned to categories. Calculated as `Total Income - Total Budgeted`.
*   **Budgeted:** The amount assigned to a category for a specific month.
*   **Activity:** The sum of all transactions (spending/income) for a category in the month.
*   **Available:** The amount available to spend. Calculated as `Budgeted + Activity + Rollover`.

## Interaction Flows

### 1. Assigning Money to a Category

**User Action:**
*   User taps on the "Budgeted" amount cell in a category row.
*   User enters a new amount (e.g., 500.00).

**System Behavior:**
1.  **Input:** The new amount is validated (must be numeric).
2.  **Update:** `BudgetingService.setCategoryBudgetedAmount` is called.
3.  **Persistence:** The app checks if a `Budget` record exists for this category/month.
    *   If yes, it updates the `budgeted` field.
    *   If no, it creates a new `Budget` record.
4.  **Recalculation:**
    *   **Available:** Recalculated immediately (`Budgeted + Activity`).
    *   **TBB:** Recalculated immediately (`Income - Sum(Budgeted)`).
5.  **Visual Feedback:** The "Budgeted" and "Available" cells update. TBB banner updates.

### 2. Moving Money (Covering Overspending)

**User Action:**
*   User notices a negative "Available" amount (Red pill).
*   User taps the red pill or long-presses the category row and selects "Move Money".
*   User selects a source category (or TBB) and a destination category.

**System Behavior:**
1.  **Validation:** Ensure source has enough funds (optional, sometimes users can move from negative).
2.  **Execution:** `BudgetingService.moveMoney` is called.
    *   Decrements `budgeted` of Source.
    *   Increments `budgeted` of Destination.
3.  **Recalculation:** TBB remains constant (sum of budgeted didn't change, unless TBB was source).
4.  **Visual Feedback:** Both categories update their "Available" amounts.

### 3. Drag and Drop from TBB

**User Action:**
*   User drags the "To Be Budgeted" banner.
*   User drops it onto a Category row.

**System Behavior:**
1.  **Prompt:** A dialog appears asking how much to assign to this category.
2.  **Defaults:** Auto-fills with `Goal Target` or remaining TBB.
3.  **Execution:** `BudgetingService.setCategoryBudgetedAmount` updates the category.

### 4. Viewing Activity Details

**User Action:**
*   User taps the "Activity" cell.

**System Behavior:**
1.  **Navigation:** Navigates to `TransactionsScreen`.
2.  **Filtering:** Pre-filters transactions by:
    *   Category: The selected category.
    *   Date Range: The selected month.
3.  **Return:** When returning, any changes to transactions (edits, deletions) trigger a budget refresh.

### 5. Goal Target Alerts

**User Action:**
*   User sees a yellow/orange indicator on the category row.

**System Behavior:**
1.  **Calculation:** `BudgetingService.calculateGoalTarget` determines the needed amount.
2.  **Comparison:** If `Budgeted < Target`, the alert is shown.
3.  **Resolution:** User can "Auto-Assign" (long press -> Underfunded) to match the target.

## Data Consistency

*   **Real-time Updates:** Changes to transactions (income/expense) update TBB and Available amounts immediately via reactive streams.
*   **Rollover:** Positive or negative Available amounts automatically roll over to the next month's "Starting Balance" (implicit in the `Available` calculation which sums all history).
*   **Zero-Based:** The system encourages `TBB = 0`. Positive TBB means money is sitting idle. Negative TBB means you have budgeted more than you have.

## Edge Cases

*   **Concurrent Edits:** If a budget is updated from another device (Sync) or process, the UI updates automatically.
*   **Offline:** All interactions work offline. Changes are queued for sync.
