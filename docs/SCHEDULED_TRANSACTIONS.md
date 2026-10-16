# Scheduled Transactions

Recurring income and expenses that the app turns into real transactions
when they are due. Managed under Settings > Scheduled Transactions
(`/settings/scheduled-transactions`).

Code: `ScheduledTransactionService`
(`lib/domain/services/scheduled_transaction_service.dart`), recurrence maths
in `lib/domain/extensions/scheduled_transaction_extensions.dart`
(`RecurrenceMath`, `ScheduledTransaction.advanced()`).

## What a schedule holds

Table `scheduled_transactions` (all columns except `id` and `auto_approve`
are nullable):

| Column | Meaning |
| --- | --- |
| `account_id`, `payee_id`, `category_id` | Copied to each occurrence. Schedules cannot be transfers or splits. |
| `amount` | Minor units, signed (negative = outflow). Never 0 or empty: the form and `ScheduledTransactionService.saveScheduledTransaction` reject it (`ValidationException`, `TransactionValidationError.zeroAmount`, as for transactions). |
| `memo` | Copied to each occurrence. |
| `frequency` | `daily`, `weekly`, `monthly`, `yearly` (default monthly). |
| `interval` | Every N periods (default 1). |
| `next_date` | Calendar day (UTC midnight) of the next occurrence; `NULL` = finished. |
| `end_date` | Optional last allowed date. |
| `occurrence_count` | Optional number of remaining occurrences. |
| `anchor_day` | Day of month (1-31) monthly/yearly schedules aim for. |
| `auto_approve` | Whether occurrences are created approved (default false). |

## Recurrence

* Daily and weekly add `N` or `7 * N` days on the calendar
  (`DateTime.utc(y, m, d + n)`), so daylight saving never shifts a day.
* Monthly and yearly aim for `anchor_day` and clamp it to the month length:
  an anchor of 31 gives Jan 31, Feb 28/29, Mar 31, Apr 30. A yearly Feb 29
  gives Feb 28 in common years. The anchor is pinned on the first advance,
  so a short month does not lose the original day.
* `advanced()` moves `next_date` to the next occurrence and decrements
  `occurrence_count` if set. The schedule finishes (`next_date = NULL`) when
  the count reaches 0 or the next date would be after `end_date`.

## Processing due occurrences

`processDueTransactions` runs after every unlock (`_initializeServices` in
`lib/app/app.dart`). For each schedule with `next_date <= today` (the user's
local calendar day):

1. In one unit of work per schedule: re-read the schedule, then for every
   due date create an occurrence and advance the schedule, and store the
   advanced schedule. A failing schedule is rolled back and logged; the
   others still run. A stored schedule with amount 0 or none (e.g. written
   by an older version) fails validation here and creates nothing.
2. Each occurrence has the deterministic id
   `DeterministicId.scheduledOccurrence(scheduleId, date)` (UUIDv5) and is
   inserted with insert-or-ignore. A second run, a crash in between or a
   second device processing the same schedule never duplicates an
   occurrence, and an occurrence the user deleted is not recreated.
3. Occurrences are `uncleared`, `approved = auto_approve`, and have the
   schedule's memo. Active rules run in automatic mode (see
   [RULES.md](RULES.md)). If the result has neither memo nor payee, a
   localised "Scheduled transaction" memo is used.

Missed occurrences are caught up: a monthly schedule not processed for
three months creates three transactions on their original dates.

`approved` does not affect balances or budget numbers; unapproved
occurrences count immediately and are only marked in the list.

## Skip

The list item menu offers Skip (`ScheduledTransactionService.skipOccurrence`):
the repository advances the schedule by one occurrence (same `advanced()`
step) without creating a transaction. The pending reminder is then
cancelled and re-scheduled for the new next occurrence, or only cancelled
when skipping finished the schedule.

## Reminders

* One local notification per schedule, the day before `next_date` at 9:00
  local time, if that moment is still in the future. Its id is derived from
  the schedule id, so re-scheduling replaces it.
* Off when Settings > Notification Settings > Scheduled Transactions is off.
* The text shows no amount unless the user enabled amounts in notifications
  (Settings > Security Settings).
* After processing, reminders are re-scheduled for every schedule
  (`rescheduleReminders`); saving a schedule (both the schedule form and
  the recurring-income form go through `saveScheduledTransaction`) and
  skipping an occurrence update its reminder; deleting a schedule cancels
  it.
