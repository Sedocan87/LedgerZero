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

A number in the text that is not a date token (`2023-10-15`, `15.10.2023`,
`15.10.`, `10/15`) and not part of a relative phrase (`in 3 days`, `3 days
ago`, `vor 3 Tagen`). Among several numbers, the first one with a decimal
part or a currency symbol wins over a bare integer (`2 Kaffee 7,50` is
7.50, `3 beers 12€` is 12.00); when none has either, the first number wins
(`Lunch 15 yesterday`). Nothing alphanumeric may touch the number, so
`15th`, `7pm` and `4:30` are never amounts. A sign directly before the
number (`refund -12.50`) is accepted and ignored; the direction comes from
the income words below. Both decimal styles and grouping are accepted
(examples with the English dot decimal separator):

| Input | Amount |
| --- | --- |
| `Coffee $4.50` | 4.50 |
| `Kaffee 12,50€` | 12.50 |
| `Rent 1,200` | 1200.00 |
| `Miete 1.234,56` | 1234.56 |
| `.99` | 0.99 |

Two bare integers remain ambiguous (`2 pizzas 15` reads 2.00); put the
amount first or write it with decimals.

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
* An explicit German date: `15.10.2023`, `15.10.23` or `15.10.` (current
  year). The trailing dot matters: `15.10` is an amount.
* Otherwise English expressions via the `chrono_dart` package, e.g.
  `today`, `yesterday`, `tomorrow`, `next friday`, `last monday`,
  `in 3 days`, `10/15` (month/day), `2025-10-25`.
* No date found: today.

Relative words count calendar days of the phone's local time zone, also
right after midnight (`gestern` typed at 01:00 on 18 October is 17
October): the parser reads the day components, never the UTC fields of an
instant. The amount is blanked out before the date is read, so `Taxi 20
yesterday` is 20.00 on yesterday, not 20:00. The result is the calendar day
as local noon; the screen stores it with `CalendarDate.fromLocalPick`.

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

### Memo

The memo of the saved transaction is the raw input text (the whole line as
typed, including amount and date words), unless a rule sets a memo in
suggest mode.

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
