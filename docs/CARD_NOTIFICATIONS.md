# Card notification capture (Android)

LedgerZero can turn payment notifications from bank, card and wallet apps
into transactions. Settings > Card notifications (shown on Android only).

iOS gives apps no access to other apps' notifications or SMS, so the
feature does not exist there. A possible iOS counterpart is an App Intent
("Add transaction") that a Shortcuts *Transaction* automation (Apple Wallet,
iOS 17+) can call; not built yet.

## Flow

1. The user grants notification access in the system settings (the app
   shows a disclosure first, as Google Play requires) and picks the apps to
   watch, each with the account its payments go to.
2. `CardNotificationListener` (a `NotificationListenerService`) ignores
   notifications of every other app without reading them. For a watched
   app it takes title and text (big text / inbox lines when present) and
   queues them in `CaptureStore`. Group summaries, ongoing and
   foreground-service notifications are skipped.
3. The listener runs in the app's process even when the app is closed, so
   it only queues. When the app starts (as soon as the database opens,
   also behind the app lock), on resume and, while the app runs, right
   after a capture, `NotificationCaptureService` parses the queue:
   * a payment with an amount in the account's currency becomes an
     **unapproved**, uncleared transaction dated on the day the
     notification arrived. The merchant becomes the payee (existing payee
     by name, else created); the category comes from the user's rules
     (suggest mode, like quick-add) or the payee's last category. Without a
     merchant the notification text is the memo. These writes are not on
     the undo stack.
   * declined payments, codes/confirmations, statements and balance
     notices are skipped.
   * anything else (no amount, no account linked, other currency) waits in
     the "Waiting for you" list, where the user can open it in the
     transaction form or dismiss it.
4. The transaction list marks captured rows as not approved; swiping
   approves, tapping edits.
5. Handled notifications are not deleted but kept in the log with their
   status (`added` with the transaction id, `skipped`, `dismissed`).
   Settings > Card notifications > Captured notifications lists the last
   30 days by app and date range, with why each was skipped ("contains
   “declined”") and whether a transaction with the same amount within a
   day already exists in the linked account. Selected entries are booked
   again (`NotificationCaptureService.addAgain`), skipped ones included;
   "Select all" leaves out skipped ones and likely duplicates. Entries
   without amount, account or matching currency open in the form.
6. When an app is added, its notifications still showing are logged as
   `found` (`CardNotificationListener.captureShowing`) and offered in the
   log, not booked: the user may have entered them already.

Android gives a listener only notifications posted while it is bound plus
the ones still showing; the system notification history is not readable by
apps. Payments from before an app was added therefore cannot be imported
from notifications (use the bank's CSV export).

## Parsing

`CardNotificationParser` is heuristic, not per bank (English and German):

* An amount needs a currency symbol or code next to it (`€12,50`,
  `12.50 EUR`, `-12,50 €`); otherwise only a lone two-decimal number counts.
  Card numbers, dates and codes are therefore not taken for amounts.
  Ambiguous separators ("1.234") follow the app's number format.
* Amounts shortly after "balance", "Kontostand", "verfügbar", "Saldo", ...
  in the same sentence are skipped; a notification with only such amounts
  is a balance notice.
* Direction: an explicit sign wins; else inflow words ("refund",
  "Gutschrift", "erhalten", ...) mean money in; else it is a payment.
* Merchant: the text after "at/bei/@" (then "to/an"; for inflows
  "from/von"), up to a verb, preposition or punctuation; else the title
  when it is not the app name or a generic word ("Kartenzahlung",
  "Payment"); else the text right after the amount.

The tests in `test/services/notification_capture/` use texts written in the
style of common apps, not verified copies. When a real app's wording is not
understood, add its text (anonymised) as a test case and adjust the rules.

## Storage and privacy

* `CaptureStore` keeps the watched apps (package, label, account id) and
  the log in the app's private SharedPreferences. The log is encrypted
  with AES-256-GCM using a key in the Android KeyStore created without user
  authentication (the listener writes while the app is closed). It
  protects the log at rest against file extraction, not against code
  running as the app on a rooted device.
* Log limits: 500 entries (handled ones dropped first); pending entries
  90 days, handled ones 30 days after the notification. Duplicate
  detection keeps SHA-256 fingerprints of (notification key, title, text)
  for 2 minutes, because apps re-post or update notifications; `found`
  entries are also checked against the fingerprints in the log.
* Stopping to watch an app deletes its log entries.
* The app picker lists apps with a notification showing, apps that
  notified while the process was alive (package names in memory only, never
  content), and installed known bank/wallet apps (`KNOWN_APPS`, each also
  declared under `<queries>` in the manifest).
* Nothing leaves the device. Factory reset deletes sources, log and key.
  Captures are not part of backups or sync until they are transactions.

## Testing on the emulator

```sh
P=com.ledgerzero.app.dev
adb -s emulator-5554 shell cmd notification allow_listener \
  $P/com.ledgerzero.app.CardNotificationListener
# Notifications posted with `cmd notification` come from com.android.shell;
# it appears in the app picker as "Shell" while such a notification shows.
adb -s emulator-5554 shell "cmd notification post -t 'Kartenzahlung' pay1 \
  'Du hast 12,50 € bei REWE bezahlt.'"
```
