# Quick Add (Natural Language Entry)

Quick Add turns a short text such as `Lunch 15 yesterday` into a
transaction. Open it from the lightning icon on the Transactions tab
(`/quick-add`, `NaturalLanguageInputScreen`). The parser is
`TransactionParser` in `lib/services/nlp/transaction_parser.dart`; it runs
entirely on the device.

The screen shows a preview (amount, payee, category, date) and an account
picker. **Create** saves directly; **Edit details** opens the full
transaction form pre-filled with the parsed values.

## What is extracted

### Amount (required)

The first number in the text that is not part of a `yyyy-mm-dd` date. Both
decimal styles and grouping are accepted (examples with the English dot
decimal separator):

| Input | Amount |
| --- | --- |
| `Coffee $4.50` | 4.50 |
| `Kaffee 12,50€` | 12.50 |
| `Rent 1,200` | 1200.00 |
| `Miete 1.234,56` | 1234.56 |
| `.99` | 0.99 |

Because the first number wins, put the amount before any other number
(`Taxi 12 in 3 days`, not `in 3 days taxi 12`).

A single separator followed by exactly three digits (`1.234`, `1,234`) is
ambiguous; it is resolved with the app's active decimal separator (Settings
number format, otherwise the language), the same rule as every other
amount field (`MoneyParser` in `lib/core/money/`):

| Input | Dot decimal separator (English) | Comma decimal separator (German) |
| --- | --- | --- |
| `Miete 1.234` | 1.23 (rounded) | 1234.00 |
| `Rent 1,234` | 1234.00 | 1.23 (rounded) |
| `Miete 1.234.567` | 1234567.00 | 1234567.00 |
| `Kaffee 1,50` / `Coffee 1.50` | 1.50 | 1.50 |

### Currency symbol

`$`, `€` or `£` is only used to show the preview amount in that currency.
The transaction is saved in the selected account; no conversion happens.

### Income or expense

A transaction is an expense unless the text contains an income word:
`deposit`, `income`, `refund`, `salary`, `paycheck`, `dividend`,
`transfer in`, `gehalt`, `lohn`, `einnahme`, `erstattung`, `dividende`,
`gutschrift` (case-insensitive, whole words only).

### Date

* German relative days: `vorgestern`, `gestern`, `heute`, `morgen`,
  `übermorgen` (`heute morgen` = today).
* Otherwise English expressions via the `chrono_dart` package, e.g.
  `today`, `yesterday`, `tomorrow`, `next friday`, `last monday`,
  `in 3 days`, `2025-10-25`.
* No date found: today.

### Payee

In this order, the first hit wins:

1. An existing payee whose name appears in the text as whole word(s)
   (case-insensitive, longest name first, so "Mario's Pizza" beats
   "Mario"; a payee "Bus" does not match "business").
2. Fuzzy match of the whole text against payee names (`fuzzy` package,
   threshold 0.3).

If no payee is found, the transaction is saved without one (or with a new
payee if you enter a name in Edit details).

### Category

1. The matched payee's auto category.
2. A built-in keyword list that maps to the default categories (English or
   German seed names; skipped if that category does not exist):
   * Groceries / Lebensmittel: grocer, grocery, groceries, supermarket,
     food, market, supermarkt, lebensmittel, einkauf
   * Dining Out / Essen gehen: restaurant, dinner, lunch, coffee, cafe,
     café, kaffee, mittagessen, abendessen
   * Transportation / Mobilität: uber, taxi, bus, train, gas, fuel, tanken,
     benzin, bahn
   * Entertainment / Freizeit: netflix, cinema, movie, spotify, kino
3. A category name that appears in the text as whole word(s) (longest
   first).
4. Fuzzy match against category names (threshold 0.3): the whole text
   first, then each word of four or more letters on its own, so a typo
   such as `Groceris 50` still finds Groceries.

Keywords and names match whole words only: a word boundary is any
character that is not a Unicode letter, mark or digit, so `bus` does not
fire inside `business`, `Müll` does not match `Müller`, and umlauts or
accents (`café`, `Bäcker`) are part of the word. German compounds
(`Supermarkteinkauf`) therefore do not match a keyword inside them.

When saving, the user's rules fill anything still empty in suggest mode
(see [RULES.md](RULES.md)).

## History

After a successful save, the exact input text is stored with the payee and
category that were saved (`parsing_history` table). Typing the identical
text again reuses a stored payee and category; amount and date are still
parsed from the text. If the same text was saved several times, the most
recent entry wins (ordered by `created_at`, newest first): your latest
correction replaces older ones. History is checked before every other step.

## Not used by Quick Add

The keyword-rule table `parsing_rules` was removed in schema v18 (nothing
in the app ever created such rules). User rules ([RULES.md](RULES.md)) are
the way to automate payees and categories.

`PayeeMatcher` (`lib/services/nlp/payee_matcher.dart`) is a separate fuzzy
matcher used by the payee picker, not by Quick Add.
