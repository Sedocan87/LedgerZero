# Natural Language Transaction Entry

LedgerZero supports entering transactions using natural language. This allows you to quickly add transactions by typing a sentence instead of filling out a form.

## Supported Formats

The parser is flexible and tries to extract the following information from your text:
1. **Amount** (Required)
2. **Payee**
3. **Category**
4. **Date**
5. **Currency** (Optional)

### Examples

**Simple Expense:**
- "Lunch 15"
- "Coffee $5"
- "Uber 25.50"

**Expense with Details:**
- "Dinner at Mario's 45.50"
- "Groceries 120 at Walmart"
- "Netflix 15.99"

**With Date:**
- "Lunch 20 tomorrow"
- "Rent 1000 due 2023-11-01"
- "Dinner on Friday 50"

**Income:**
- "Salary 3000"
- "Deposit 500"
- "Refund 50 from Amazon"

## How it Works

### Amount Extraction
The parser looks for numbers. It handles:
- Decimals: `15.50`, `.99`
- Integers: `15`
- Currency symbols: `$15`, `15€`, `£15`
- Commas: `1,200.00`

### Payee Recognition
- **Exact Match**: If you type a name of an existing payee (e.g., "Walmart"), it will be recognized.
- **Fuzzy Match**: The parser attempts to match typos (e.g., "Starbuks" -> "Starbucks").
- **New Payees**: If the payee is not recognized, you can create it when saving the transaction.

### Category Recognition
- **Payee Default**: If the recognized payee has a default category (e.g., Walmart -> Groceries), it is used automatically.
- **Keywords**: Certain words automatically map to categories:
  - "Food", "Dinner", "Lunch" -> **Dining Out**
  - "Uber", "Taxi", "Gas" -> **Transportation**
  - "Movie", "Netflix" -> **Entertainment**
- **Direct Match**: If you type a category name (e.g., "Groceries"), it matches.
- **Fuzzy Match**: Matches similar names (e.g., "Groceris" -> "Groceries").

### Date Parsing
The parser understands natural language dates:
- "today", "tomorrow", "yesterday"
- "next friday", "last monday"
- "in 3 days"
- "2023-10-25"

### Income Detection
Transactions are assumed to be expenses unless words like "deposit", "income", "salary", "refund" are found.

## Tips
- Type the amount clearly.
- Include the payee name if it's specific.
- You can mix the order (e.g., "20 Lunch" or "Lunch 20").
