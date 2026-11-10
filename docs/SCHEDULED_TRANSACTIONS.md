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
| `amount` | Minor units, signed (negative = outflow). The form enters it like the transaction form: an Outflow \| Inflow choice (Outflow by default) and an unsigned amount; editing shows the stored side and the absolute amount. Never 0 or empty: the form and `ScheduledTransactionService.saveScheduledTransaction` reject it (`ValidationException`, `TransactionValidationError.zeroAmount`, as for transactions). The same validation rejects an end date before the next date (`scheduleEndBeforeNextDate`) and an interval below 1 (`scheduleInvalidInterval`); the form shows the message. |
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

`processDueTransactions` runs when the database opens (`_initializeServices`
in `lib/app/app.dart`) and on every resume (`_bookDueThenFill`; the
new-month fill follows it). With sync set up it first lets the sync run
that started with the session or the resume finish, for at most 10
seconds, so it sees what the other phone already booked, edited or
skipped; offline, with manual sync or without sync nothing is waited for.
For each schedule with `next_date <= today` (the user's local calendar
day):

1. In one unit of work per schedule: re-read the schedule, then for every
   due date create an occurrence and advance the schedule, and store the
   advanced schedule. A failing schedule is rolled back and logged; the
   others still run. A stored schedule with amount 0 or none (e.g. written
   by an older version) fails validation here and creates nothing.
2. Each occurrence has the deterministic id
   `DeterministicId.scheduledOccurrence(scheduleId, date)` (UUIDv5) and is
   inserted with insert-or-ignore. A second run, a crash in between or a
   second device processing the same schedule never duplicates an
   occurrence, and an occurrence the user deleted is not recreated (see
   "Two phones" for what keeps the other phone's copy from replacing an
   edited or deleted one).
3. Occurrences are `uncleared`, `approved = auto_approve`, and have the
   schedule's memo. Active rules run in automatic mode (see
   [RULES.md](RULES.md)). If the result has neither memo nor payee, a
   localised "Scheduled transaction" memo is used.

Missed occurrences are caught up: a monthly schedule not processed for
three months creates three transactions on their original dates. One run
books at most 31 occurrences per schedule
(`ScheduledTransactionService.maxOccurrencesPerRun`); a next date set far
back (the form allows a year) is caught up over the following runs instead
of flooding the list with hundreds of unapproved rows at once.

Schedules that book nothing:

* A schedule whose account is closed (or is the partner's personal
  account) is skipped and left unchanged; it books again once the account
  is reopened. The schedules list marks it ("Account closed: nothing is
  booked"), and closing an account that active schedules target asks the
  user to confirm (account screen).
* A schedule whose next date lies after its end date is finished
  (`next_date = NULL`) without booking.

`approved` does not affect balances or budget numbers; unapproved
occurrences count immediately and are only marked in the list.

## Two phones

Both phones of a household run the catch-up, and one may run it before it
has received what the other did. The deterministic id only prevents a
second row; the conflict rule of sync (newest `updated_at` wins) decides
which version of the row stays. So what the catch-up writes is stamped
with times that do not depend on when or where it ran
(`ScheduleStamps`, `lib/domain/services/schedule_stamps.dart`), like the
new-month fill:

* **An occurrence** gets `updated_at` = 00:00 UTC of the day before its
  date (the repository's `insertGeneratedTransactionOrIgnore` keeps it).
  Its calendar day begins nowhere before 10:00 UTC of that day, so every
  edit, approval, clearing or delete a person makes afterwards is newer:
  the other phone booking the same occurrence later does not undo it, on
  either phone. Two untouched copies are identical apart from the memo
  language; sync records no conflict for an untouched generated copy.
* **The schedule row** advanced by the catch-up gets the stored
  `updated_at` plus one millisecond per occurrence
  (`ScheduledTransactionRepository.storeCatchUp`). It never moves
  backwards; two phones advancing the same version by the same number of
  occurrences write the same time and content, the one that advanced
  further is newer; an edit or a skip by a person carries the time it was
  made and wins over an advance computed from the version before it.
  (When that leaves the schedule behind an occurrence that is already
  booked, the next catch-up advances it again without booking twice.)
* **A skip** also stores the skipped occurrence as a deleted transaction
  with its deterministic id (see below), which a copy booked by the other
  phone loses against.

Not covered: a phone that is offline when it books uses the schedule as it
knows it. If the partner changed the schedule's amount before the due date
and that edit has not arrived, the occurrence is booked with the old
amount (on both phones after sync); correct it by hand.

## Skip

The list item menu offers Skip (`ScheduledTransactionService.skipOccurrence`):
the repository advances the schedule by one occurrence (same `advanced()`
step) and no transaction appears. In the same unit of work the skipped
occurrence is stored as a **deleted** transaction with its deterministic
id: on this phone that is the state "booked and deleted", which is never
recreated; on a paired phone that books the occurrence before it learns
of the skip, the deleted row is the newer version, so the booking
disappears there as well instead of spreading to both phones. Deleted
transactions count nowhere. The pending reminder is then cancelled and
re-scheduled for the new next occurrence, or only cancelled when skipping
finished the schedule.

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
