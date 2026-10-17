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
3. The database is encrypted with the user's key and closed while the app
   is locked, so nothing is booked then. After every unlock, on resume and
   (while unlocked) right after a capture, `NotificationCaptureService`
   parses the queue:
   * a payment with an amount in the account's currency becomes an
     **unapproved**, uncleared transaction dated on the day the
     notification arrived. The merchant becomes the payee (existing payee
     by name, else created); the category comes from the user's rules
     (suggest mode, like quick-add) or the payee's last category. Without a
     merchant the notification text is the memo. These writes are not on
     the undo stack.
   * declined payments, codes/confirmations, statements and balance
     notices are dropped.
   * anything else (no amount, no account linked, other currency) waits in
     the "Waiting for you" list, where the user can open it in the
     transaction form or dismiss it.
4. The transaction list marks captured rows as not approved; swiping
   approves, tapping edits.

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
  the queue in the app's private SharedPreferences. The queue is encrypted
  with AES-256-GCM using a key in the Android KeyStore created without user
  authentication (the listener must write while the app is locked). It
  protects the queue at rest against file extraction, not against code
  running as the app on a rooted device.
* Queue limits: 200 entries, 90 days. Duplicate detection keeps SHA-256
  fingerprints of (notification key, title, text) for 2 minutes, because
  apps re-post or update notifications.
* The app picker lists apps with a notification showing, apps that
  notified while the process was alive (package names in memory only, never
  content), and installed known bank/wallet apps (`KNOWN_APPS`, each also
  declared under `<queries>` in the manifest).
* Nothing leaves the device. Factory reset deletes sources, queue and key.
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
