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
   also behind the app lock), on resume, right after a capture while the
   app runs, and after every sync run, `NotificationCaptureService` parses
   the queue. **An amount alone is not a payment**: a notification is
   booked only when the parser positively finds a payment or incoming
   money (see Parsing).
   * a payment (or incoming money) with an amount in the account's
     currency becomes an **unapproved**, uncleared transaction dated on the
     day the notification arrived. The merchant becomes the payee (existing
     payee by name, else created); the category comes from the user's rules
     (suggest mode, like quick-add) or the payee's last category. Without a
     merchant the notification text is the memo. These writes are not on
     the undo stack.
   * declined, failed, blocked and reverted payments, codes/confirmations,
     statements, balance notices, weekly/monthly summaries, promotions,
     price alerts and account notices are skipped (`skipped`; the log says
     which phrase decided).
   * a notification that lists **several payments, one per line** (an
     inbox-style notification) is booked line by line; its log entry holds
     all transaction ids. A line that an earlier notification of the same
     app showed within 12 hours is not booked again (apps add lines to a
     notification that is still showing). Several amounts on one line, or
     lines that are not clearly payments, wait for the user; never is only
     the first one booked.
   * a payment that looks like one already in the linked account is logged
     as `duplicate`, not booked; the log offers "Add anyway"
     (`NotificationCaptureService.isSamePayment`). Same account and amount
     are required, and then:
     * the existing row was booked from a notification of the **same
       app**: another merchant is another purchase. With a matching
       merchant (`merchantsMatch`: case, umlauts, legal forms and "sagt
       danke" ignored; the first word of one name must appear in the
       other, or one name contains the other) it is a duplicate only when
       the two notifications are at most **5 minutes** apart (the app
       posted the payment again), or when the existing row is an open
       authorisation and this is its booking, at most 5 days later. A
       repeat purchase hours or a day later (the daily canteen lunch, the
       second coffee) is booked.
     * the existing row was booked from a notification of **another app**
       (Google Wallet and the bank app): at most 24 hours apart; when
       both name a merchant and the names do not match, at most 2 hours
       (Wallet and the bank name merchants differently).
     * the existing row was entered otherwise (by hand, import, schedule,
       the other household phone): dated the **same day**, and when both
       have a merchant / payee the names must match.

     The existing row's payee name and the merchant of the notification it
     came from both count, so a payee renamed by a rule still matches.
   * **authorisations** ("vorgemerkt", "reserviert", "pending",
     "autorisiert"): booked like a payment, with the memo "Reserved amount,
     the final amount may differ" when a merchant is known. An
     authorisation is *open* while its transaction still has the authorised
     amount and no later booking notice of the same app, amount and
     merchant has confirmed it. For an open authorisation of the same app,
     at most 5 days old:
     * a release notice ("Vormerkung aufgehoben", "released") is not booked
       and deletes the authorisation's transaction;
     * a correction that names the old amount ("62,31 € statt 150,00 €",
       "instead of") changes the amount of that transaction;
     * a later payment of **another amount** at the same merchant that is
       not itself an authorisation is not booked on top and not swapped in
       silently either: it waits with the question "Is this the final
       amount of the 150,00 € that was reserved earlier?" (*Replace*
       changes the transaction, *Add separately* books a second one). A
       bank that words every card payment as an authorisation never
       triggers the question.
   * anything else waits in the "Waiting for you" list, where the user can
     open it in the transaction form or dismiss it: no amount, no account
     linked, other currency, an amount that is not clearly a payment,
     several amounts. Notifications without an amount from Google Play
     services (`NotificationCaptureService.noisyPackages`) are dropped
     instead, also from the log, because that package posts far more than
     payments.
   * every entry is handled on its own: when booking one throws, it is
     logged as `failed` with the error class and message (also written to
     the diagnostic log, which keeps warnings and errors in release
     builds), the run goes on with the next entry, and the log offers
     "Retry". A failed entry is no longer pending, so it is not retried on
     every start.
   * **both household phones**: when both phones watch the app of a shared
     account, each books the payment before sync delivers the other's row.
     After sync each run compares this phone's recent captured rows (3
     days, unapproved, amount unchanged, not added by the user) with rows
     it did not book: same account, day and amount, matching merchant
     (`merchantsMatch`, so the phones may have read the merchant
     differently). If exactly one such row exists, exactly one phone gives
     way: the one whose copy is unapproved while the other is approved,
     else the one with the greater transaction id. It deletes its own row
     and logs the notification as `duplicate` ("Add anyway" if it was a
     separate purchase after all). If the other row arrived first, the
     normal duplicate check holds the capture. Watching a shared account's
     app on one phone only avoids the detour.
   * **what the user is told**: `CaptureAttentionNotifier`
     (`captureAttentionProvider`) keeps the result of each run and asks the
     service for `attention()`: notification access revoked, listener not
     connected (checked at start and on every resume, after a 2-second
     grace for the system to bind it), capture storage reset, and the ids
     of waiting, failed and duplicate entries. Home shows a banner
     ("Card notifications need a look") with *Review* (opens the Card
     notifications screen) and *Dismiss*; the Settings entry carries a
     badge. Dismissing, or opening the Card notifications screen, marks the
     listed entries as seen (ids in SharedPreferences); the banner returns
     for new entries or another problem. The Card notifications screen
     lists the counts of held duplicates and failed bookings above the
     link to the log.
4. The transaction list marks captured rows as not approved; swiping
   approves, tapping edits.
5. Handled notifications are not deleted but kept in the log with their
   status (`added` with the transaction id, `skipped`, `dismissed`,
   `duplicate`, `failed` with the error). Settings > Card notifications >
   Captured notifications lists the last 30 days by app and date range,
   with why each was skipped ("contains “declined”") and whether a
   transaction that looks like the same payment (same rules as above)
   already exists in the linked account. Selected entries are booked again
   (`NotificationCaptureService.addAgain`), skipped ones included (the
   entry is then marked as added by the user and never taken back); an
   `added` entry whose transaction still exists cannot be selected (it
   would be doubled) and "Select all" leaves out skipped ones and likely
   duplicates. Entries without amount, account or matching currency open
   in the form. The bin icon deletes the listed handled entries (waiting
   ones stay). Both screens run the pending entries first and, when that
   fails, still show their content with the error in a banner.
6. When an app is added, its notifications still showing are logged as
   `found` (`CardNotificationListener.captureShowing`) and offered in the
   log, not booked: the user may have entered them already.

Android gives a listener only notifications posted while it is bound plus
the ones still showing; the system notification history is not readable by
apps. Payments from before an app was added therefore cannot be imported
from notifications (use the bank's CSV export).

## Parsing

`CardNotificationParser` is heuristic, not per bank (English and German).
The result is one of: `outflow`, `inflow`, `ignored` (skipped, with the
phrase), `unreadable` (no amount), `unclear` (an amount, but nothing says
payment; waits for the user) and `several` (several payments; with one
part per line they are booked, else it waits).

* An amount needs a currency symbol, code or the word "Euro" next to it
  (`€12,50`, `12.50 EUR`, `-12,50 €`, `12,50 Euro`); otherwise only a lone
  two-decimal number counts, and not one after "am"/"on" or before
  "um"/"Uhr"/a time ("am 18.10 um 09:28"). Card numbers, dates and codes
  are therefore not taken for amounts. Ambiguous separators ("1.234")
  follow the app's number format; thousands may be grouped with a
  (narrow) no-break space, or with a plain space when decimals follow
  ("1 234,56 €").
* Amounts after "balance", "Kontostand", "verfügbar", "Saldo", ... in the
  same sentence are skipped; a notification with only such amounts is a
  balance notice.
* Which amount: the title's amount counts once when the text repeats it;
  of "62,31 € statt 150,00 €" the first is the payment and the second the
  amount it replaces; when the payment is named in two currencies
  ("25,00 USD (23,10 €)") the one in the linked account's currency is
  taken; one amount merely repeated is one payment. More than one amount
  left means `several`.
* Not a payment, wherever the words stand: codes and log-ins (matched in
  forms a merchant name does not take: "TAN:", "pushTAN", "OTP code",
  "new login", so "Tan Thai Imbiss" is a merchant), statements, and
  everything that says the payment did not happen ("declined", "failed",
  "blocked", "reverted", "not successful", "couldn't process",
  "insufficient funds", "abgelehnt", "zurückgewiesen", "blockiert",
  "konnte nicht", "nicht möglich", "nicht autorisiert", "mangels Deckung",
  ...). A bare "not" is not one of them: "If this wasn't you, call us"
  follows real payments. "cancelled"/"storniert" count only in the title
  or in the clause of the amount, so "Your subscription was cancelled;
  €9.99 refunded" is a refund.
* Not a payment although payment words occur, in the title or the
  sentence of the amount: summaries (a period such as "this week" or
  "diesen Monat" together with "spent"/"ausgegeben"; "Beitrag für diesen
  Monat: 9,99 € abgebucht" stays a payment), promotions ("refer a
  friend", a sentence starting with "Spare", "Get", "Erhalte"), and a
  change in per cent next to the amount.
* Direction and nature must be positive:
  * an explicit sign wins (`-` outflow, `+` inflow);
  * else inflow words, also inside German compounds ("Zahlungseingang",
    "Geldeingang", "Gehaltseingang", "Gutschrift", "erhalten",
    "bekommen", "empfangen", "received", "refund", "Erstattung",
    "zurückgebucht", "topped up", "Cashback", "Zinsen", ...; not
    "Posteingang"). They win over payment words, because refunds and
    returned debits name the payment they undo;
  * else payment words ("paid", "spent", "purchase", "charged",
    "Kartenzahlung", "bezahlt", "Lastschrift", "abgebucht", "belastet",
    "vorgemerkt", ...). "Payment"/"Zahlung" counts unless the text only
    says who it came from ("Zahlung von Max Mustermann: 50,00 €"); words
    for a movement in either direction ("Umsatz", "Buchung",
    "transaction", "Überweisung") count only with where it went
    ("... to BEST BUY", "... bei REWE");
  * else the wallet layout: the amount first, then "at/bei merchant"
    ("€3.55 at Kiosk"), or the merchant as the title and the amount with
    the card as the text ("€12.50 with Visa •••• 1234").

  The words are looked for in the title and the sentence of the amount
  first, then in the whole text. A title that is just the app's name does
  not count. Without any of these the result is `unclear`, unless a price
  alert or account notice phrase ("steht bei", "erreicht", "im Minus",
  "ist verfügbar", "/Monat", ...) or a balance word makes it `ignored`.
* "autorisiert", "vorgemerkt", "reserviert", "pending", "authorised", ...
  mark the payment as an authorisation (`isAuthorisation`); "aufgehoben",
  "released" mark a release (`isRelease`, not booked).
* Merchant: the text after "at/bei/@" (then "to/an"; for inflows
  "from/von"), up to a verb, preposition or punctuation ("gesendet",
  "überwiesen", "sent", "received", ...); else the title when it is not
  the app name or a generic word ("Kartenzahlung", "Payment"); else the
  text right after the amount; else a name in parentheses. The dot of an
  abbreviation does not end the name ("Dr. Müller Apotheke").
* Google Wallet: on Pixels the tap-to-pay notification is posted by Google
  Play services (`com.google.android.gms`), not by the Wallet app, so the
  picker offers both ("Google Wallet (tap to pay via Google Play
  services)"); watch the one that notifies, or both.

Known limits: a reversal ("reverted", "rückgängig") is skipped, not booked
as money back, so the payment it undoes has to be deleted by hand; a
securities order ("Kauf: 10 Tesla zu 250,00 €") reads as a purchase of
the quoted price; a wallet wording other than the two layouts above waits
for the user instead of being booked.

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
* Log limits: 500 entries; pending entries 90 days, handled ones 30 days
  after the notification. When the limit is reached, handled entries go
  first, then waiting notifications of Google Play services that contain
  nothing like an amount, and only then the oldest waiting payments.
  Notifications of Google Play services without any digit are not stored
  at all, and at most 100 of its waiting notifications without anything
  like an amount are kept (`CaptureStore.NOISY_PACKAGES`). The log is
  written with `commit()`, so a capture survives the process being killed
  right after it. Duplicate
  detection keeps SHA-256 fingerprints of (notification key, title, text)
  for 2 minutes, because apps re-post or update notifications; `found`
  entries are also checked against the fingerprints in the log.
* Only when the key or the stored log is unusable for good does
  `CaptureStore` start over: the key is gone, permanently invalidated or
  unrecoverable (`KeyPermanentlyInvalidatedException`,
  `UnrecoverableKeyException`), or the log does not authenticate or is
  corrupt (`AEADBadTagException`, not Base64, not JSON). It then records
  the time (`storageResetAt`); Home and the Card notifications screen
  show "capture storage was reset on <date>" until the user dismisses it.
  The log is never dropped silently. Any other KeyStore or cipher error
  (a busy or briefly unavailable key store) leaves key and log untouched:
  the call fails with `CaptureStoreUnavailableException` and is repeated
  at the next start, resume or capture; a notification that arrives
  meanwhile waits in memory and is written with the next call that
  succeeds.
* Stopping to watch an app drops its waiting entries; its handled entries
  stay in the log until the user deletes them there.
* Listener binding: `isAccessGranted` only says the package is enabled.
  `CardNotificationListener` tracks whether the system has actually bound
  it (`connected`, exposed as `isListenerConnected`).
  `NotificationListenerService.requestRebind` is called when access is
  granted but the listener is not connected: when the activity starts,
  whenever the app asks `isListenerConnected` (start and every resume),
  and from `PackageReplacedReceiver` (`MY_PACKAGE_REPLACED`) right after
  an app update, when Android may leave the listener unbound until a
  reboot. Home and the Card notifications screen say "access granted, but
  the listener is not connected" with what to do.
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
