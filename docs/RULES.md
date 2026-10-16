# Auto-Categorization Rules

LedgerZero includes a powerful rule engine to automate transaction categorization and cleanup. This guide explains how to create effective rules.

## Rule Structure

Each rule consists of:
1.  **Name**: A descriptive name (e.g., "Uber to Transport").
2.  **Match Logic**:
    -   **AND**: All conditions must match.
    -   **OR**: At least one condition must match.
3.  **Conditions**: Criteria to match transactions.
4.  **Actions**: Changes to apply when a match is found.
5.  **Priority**: Rules are applied in order.

## Conditions

Supported conditions include:
-   **Payee**: Matches the payee name (e.g., "Uber").
-   **Amount**: Matches the transaction amount.
-   **Description (Memo)**: Matches the memo or description field.

### Operators
-   **Equals**: Exact match (case-insensitive).
-   **Contains**: The text contains the value (e.g., "Uber" matches "Uber Eats").
-   **Starts With**: The text starts with the value.
-   **Ends With**: The text ends with the value.
-   **Greater Than / Less Than**: Numeric comparison (for Amount).
-   **Regex**: Regular expression matching.

## Actions

When a rule matches, one or more actions can be applied:
-   **Set Category**: Assigns a category.
-   **Set Payee**: Renames the payee (e.g., "Uber *123" -> "Uber").
-   **Set Account**: Moves the transaction to another account (use with caution).
-   **Set Memo**: Overwrites the memo.
-   **Mark Cleared**: Sets the status to Cleared (or Uncleared).
-   **Mark Approved**: Sets the status to Approved.

## Regular Expressions (Regex)

For advanced matching, use the `Regex` operator. LedgerZero uses Dart's `RegExp` engine.

**Examples:**
-   `^Uber`: Matches strings starting with "Uber".
-   `Amazon.*Marketplace`: Matches "Amazon" followed by anything, then "Marketplace".
-   `\d{3}`: Matches any 3 digits.

**Note:** Regex matching is slower than simple text matching. Use sparsely.

## Conflicts & Priority

Rules are ordered by their priority number; the top of the Rules screen is
priority 0, the highest priority.
-   **The highest-priority matching rule wins for each field.** All matching
    rules are applied, but a lower rule can only set fields that no higher
    rule already set.
-   If Rule A (top) sets Category to "Food" and Rule B (below) sets Category
    to "Groceries" and Memo to "Weekly shop", the result is Category "Food"
    and Memo "Weekly shop".

### When rules run

-   **Manual entry and quick-add**: rules only *suggest* values for empty
    fields (category, payee, memo) before you save; they never override what
    you chose and never change the account, cleared or approved status.
-   **CSV import and scheduled transactions**: rules fill empty category,
    payee and memo and apply "mark cleared" / "mark approved"; they never move
    a transaction to another account. For imports, a matching rule's category
    beats the payee's remembered default category.
-   **"Apply rules to all transactions"** (Rules screen menu): every action is applied
    and overwrites existing values, except that transfer legs, split lines
    and split parents keep their account, transfer legs and split parents
    never get a category, and reconciled transactions keep their status.
-   Saving a transaction with a payee and a category only remembers that
    category as the payee's default; it never creates a rule and never
    changes other transactions.

Use the "Rule conflicts" warning in the Rules screen to identify rules that might be fighting each other.

## Best Practices

1.  **Keep it Simple**: Use "Contains" or "Equals" whenever possible.
2.  **Order Matters**: Place specific rules (e.g., "Amazon AWS") *above* generic rules (e.g., "Amazon") so the specific one wins.
3.  **Test**: Use "Apply rules to all transactions" with caution. Create a backup first (Settings > Backup & Export); "Export rules" in the Rules screen menu saves your rules.
4.  **Performance**: Avoid having hundreds of complex Regex rules. Simple text matching is very fast.
