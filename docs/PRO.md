# LedgerZero Pro

LedgerZero is free to download. **LedgerZero Pro** is a one-time purchase
(no subscription) on Google Play that unlocks the features for households
and power users. Nobody's data is ever locked in: everything needed to keep
a budget, and to get the data out again, stays free.

## Free and Pro

| Free | Pro |
|---|---|
| Budgeting with unlimited accounts, categories and transactions | Wi-Fi sync between the phones of a household (each phone that syncs needs Pro) |
| Credit-card payment categories, reconciliation | Card notification capture |
| CSV and YNAB import, CSV export | PDF export of reports |
| Reports on screen, CSV and image export | Budget templates (save, apply) and "Fill new months automatically" |
| Backups, Android backup, "Save to…" | Rules |
| App lock, scheduled transactions, payees | |
| "Copy from previous month" and "Fill like last month" | |

The split lives in one place: `ProFeatures.gated` in
`lib/core/constants/pro_features.dart`. Removing a feature from that set
makes it free everywhere: its gate, its PRO badge and its line on the Pro
screen all read the set.

## How a feature is gated

* **Screens** (Wi-Fi sync, card notifications, rules): the route redirects
  to the Pro screen (`/settings/pro?feature=…&next=…`) while Pro is locked,
  also for deep links such as a sync-failure notification. After the
  purchase, "Continue" opens the screen that was asked for.
* **Actions** (save/apply a template, the automatic fill setting, PDF
  export): `ensureProFeature` opens the Pro screen first and lets the action
  go on only if Pro was unlocked there.
* **Background work** stops while Pro is locked, so a refunded purchase
  really ends the feature: the sync controller does not sync
  (`SyncController.setAllowed`; the setup, the pairing and the outgoing
  changes are kept), captured card notifications are not booked (the
  native store keeps them until Pro is unlocked again), and the automatic
  fill of new months does not run.
* Settings shows a "LedgerZero Pro" entry at the top and PRO badges on the
  gated entries; the budget menu marks the template entries.

## Purchase

* One non-consumable in-app product, id `ledgerzero_pro`
  (`ProFeatures.productId`), bought with the official `in_app_purchase`
  plugin (Google Play Billing). There is no server of ours and no
  third-party purchase service; the Play Store app confirms the purchase on
  the phone.
* `ProController` (`lib/presentation/providers/pro_provider.dart`)
  remembers the unlock in the preferences (`pro_unlocked`), so Pro works
  offline and from the first frame. At every start it asks Google Play
  again (`queryPastPurchases`): a purchase made while the app was closed
  unlocks Pro, a refunded one locks it again; when Play cannot answer
  (offline, no Play Store), the remembered state stays.
* A paid purchase is acknowledged at once (Play refunds purchases that are
  not acknowledged within three days); one left unacknowledged by a killed
  app is acknowledged at the next start.
* A pending payment (for example cash at a shop) does not unlock Pro until
  Play reports it as paid.
* "Restore purchase" on the Pro screen asks Play for the Google account that
  is signed in to the Play Store. A new phone restored from Android backup
  starts unlocked and Play confirms it.
* A factory reset keeps the Pro unlock (it belongs to the Google account,
  not to the budget).
* There is no server-side receipt check: a determined user can patch the
  APK. For a niche one-time purchase that is accepted.

## Development builds

The development flavour (`com.ledgerzero.app.dev`) has no Play product. Its
Pro screen has a switch "Pro unlocked (development build)" that unlocks Pro
without a purchase; staging and production builds ignore it.

## Play Console setup

1. Upload a build to a testing track (in-app products can only be created
   once the app has a build with the billing permission, which the plugin
   adds).
2. Monetise > Products > In-app products: create `ledgerzero_pro`, a
   one-time product, with the EN and DE title and description and the
   price (prices per country follow from it). Activate it.
3. Optional: turn on Family Library for the product, so one purchase covers
   the family group (useful for Wi-Fi sync between partners).
4. Add the testers' Google accounts as licence testers (Settings > Licence
   testing): they buy with test cards and are not charged.
5. Test on a phone with the build installed from the testing track: buy,
   cancel, a slow test card (pending), restore after reinstall, refund in
   the Play Console (Pro locks at the next start).
6. Data safety form: purchases are handled by Google Play; the app itself
   collects no purchase data.
