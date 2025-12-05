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

Rules are applied sequentially based on their priority (order in the list).
-   **Top rules run first.**
-   Later rules can overwrite changes made by earlier rules.
-   If Rule A sets Category to "Food" and Rule B (lower priority) sets Category to "Groceries", the final result is "Groceries".

Use the "Conflicts" warning in the Rules screen to identify rules that might be fighting each other.

## Best Practices

1.  **Keep it Simple**: Use "Contains" or "Equals" whenever possible.
2.  **Order Matters**: Place specific rules (e.g., "Amazon AWS") *below* generic rules (e.g., "Amazon") if you want the specific one to take precedence. Wait, actually, if you want specific to override generic, it should be *after* (lower in list) or the generic one should exclude the specific case. LedgerZero applies all matching rules in sequence.
3.  **Test**: Use the "Apply to All" feature with caution. Backup your data first (Export Rules/Data).
4.  **Performance**: Avoid having hundreds of complex Regex rules. Simple text matching is very fast.
