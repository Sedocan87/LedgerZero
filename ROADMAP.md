# LedgerZero v1 Roadmap

**Goal:** a privacy-first, one-time-purchase envelope budgeting app for Android. It should be good enough that someone tired of YNAB's subscription would pay €29–49 for it.

**v1 scope:** Android only. English and German. Accounts, envelope budget, transactions (manual and quick-add), scheduled transactions, rules, reports, CSV and YNAB import, encrypted local database, backup and restore, sync via Google Drive or phone to phone on the home Wi-Fi. The `ios/` project stays in the repository but iOS is not shipped or tested in v1 (see "Later").

**Out of scope for v1:** PDF/OCR import, ML categorisation, Mint import, desktop and web, home-screen widgets. All of these were removed on the `slim-down` branch and remain in `main`'s history if needed later.

---

## Phase 0: Slim down ✅ (done)

- Removed P2P sync, PDF/OCR import, BERT categoriser, Mint migration, desktop and web targets, home widgets, debug screens and leftover generated files (115 files).
- Fixed the build. Raised the SDK floor to 3.12 (needed for private named parameters) and moved SQLCipher to `sqlite3`'s build hook (`hooks.user_defines.sqlite3.source: sqlcipher`).
- Fixed `ios/Runner.xcodeproj`, which had been unparseable since the "Configure iOS app signing" commit. Flutter then auto-migrated the project to iOS 15, SwiftPM and the UIScene lifecycle.
- Fixed "file is not a database" after restarting an unfinished onboarding; factory reset also deletes the `-wal`/`-shm` files.

## Phase 1: Make it trustworthy ✅ (done, except real-device checks)

**Money and data**
- [x] **Money as integer minor units.** Schema v15 converts every REAL money column with `ROUND(x*100)`; entities, DAOs, imports, exports, backups, sync payloads, rules and the NLP parser use `int` (`lib/core/money/`).
- [x] **`BudgetingService` audit.** One budget identity (balances, activity, TBB) with an invariant test (`budget_invariant_test.dart`) and table-driven tests; dates are UTC calendar days.
- [x] **Round-trip tests.** Backup → restore (`backup_restore_roundtrip_test.dart`, plus on-device), CSV export → import (`csv_round_trip_test.dart`), YNAB import tests, undo round trips.

**Security**
- [x] **Fail closed.** The connection refuses to open without a key and checks `PRAGMA cipher_version` (`lib/data/database/sqlcipher.dart`).
- [x] **Raw hex key.** A random 256-bit data key is passed as `PRAGMA key = "x'…'"`.
- [x] **Key handling reviewed.** Key vault with Argon2id (46 MiB, 2 passes) password wrapping, independent recovery key, optional hardware-bound biometric wrap; password change only re-wraps; legacy installs migrate on first login (`lib/services/security/key_vault.dart`, docs/ENCRYPTION.md).
- [x] **Auto-lock locks.** Locking closes the SQLCipher connection and drops the key (`session_provider.dart`); sync pauses while locked.

**Sync**
- [x] **Conflict rule decided and shown.** Last-writer-wins per row by the row's UTC `updated_at`, device-id tiebreak; overwritten local edits appear in Sync settings → conflicts ("keep mine" / "dismiss").
- [x] **Recovery.** Failing change files are quarantined instead of blocking; after a restore the device rebuilds its sync state from the newest snapshot (`sync_rebootstrap.dart`) without duplicating data.
- [x] **Two-device matrix, simulated.** `sync_simulation_test.dart` covers offline edits on both sides, deletes, double edits and bootstrap across simulated devices. The real-device matrix is still open (see below).

**Tests and tooling**
- [x] **Hanging router test fixed**; the suite is green (939 unit/widget tests, `bash tool/check.sh`).
- [x] **Failing tests triaged**; mocks regenerated, stale and AI-noise tests removed, missing tests added.
- [x] **Dependency refresh** (see "Audit fixes" below): `pdf` 3.13.1 without the `image` pin, Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0 with built-in Kotlin, Java 17.
- [x] **Dead code and docs removed.** No `developerMode`, `delta_debug_utils.dart` or removed-feature l10n keys; `PerformanceMonitor` only runs in debug/profile; README and docs rewritten.
- [x] **Integration tests** (onboarding → budget, relaunch/unlock, CSV import, lock; backup/restore; v14 → v17 upgrade) pass on the iOS Simulator and an Android emulator.
- [ ] **Manual smoke test on a real Android phone**, every flow from onboarding to sync (see the real-device list below).

**Exit criteria:** all tests green ✅; money stored as integers ✅; encrypted DB verified on simulator/emulator ✅ and on real phones (open); two-device sync matrix on real devices (open); no crashes across a full manual run (open).

## Audit fixes (2026-10)

A code audit in October 2026 was worked off in eight packages:

1. **Money and schema v15:** integer minor units everywhere, derived balances no longer stored, `updated_at` on every synced table, one formatter for amounts/dates honouring currency, locale and format settings, locale-aware decimal-comma input, UTC storage of dates.
2. **Ledger correctness:** two-way linked transfers, the income/TBB rule, split and delete semantics, atomic move-money, undo/redo, schedules that keep their day of month, deterministic UUIDv5 ids (budget rows, seeded categories, scheduled occurrences), correct YNAB/CSV import, transaction screen split into a controller and form widgets.
3. **Security:** key vault (data key wrapped by password, recovery key, biometrics), fail-closed SQLCipher, backup format v2 (always encrypted), safe exports (CSV formula injection), local-only logs, FLAG_SECURE and app-switcher cover.
4. **Sync v2 (schema v17):** encrypted change files, sync passphrase and manifest, LWW per row, quarantine, snapshot bootstrap, lifecycle tied to unlock/resume/lock.
5. **Presentation and state:** provider consolidation, refresh bugs, notifications, accessibility (semantics on amounts and charts), dead code removed.
6. **Localisation:** every user-facing string in ARB, complete German translation, `de_DE` number/date formats.
7. **Tests:** green suite, no hangs, noise removed, integration tests on simulator/emulator.
8. **Dependencies, builds, docs:** dependency refresh, Android tooling on AGP 9, chart colours from the theme (`ChartPalette`), README and docs rewritten, `DATABASE_SCHEMA.md` generated from the v17 schema.

## Phase 2: Design and UX (about 2–3 weeks)

The app still looks like default Material 3 with a teal seed colour. The design is what makes people pay, so this phase matters as much as Phase 1.

- [ ] **Pick a visual identity:** typeface with tabular figures for amounts, a palette that isn't stock Material (charts already take their colours from the theme), icon style, app icon and splash.
- [ ] **Budget screen first.** Clear TBB banner, fast assignment, readable over/under states, good month navigation.
- [ ] **Transaction entry in under 5 seconds.** Make quick-add the default entry path, payee and category autocomplete up front. (The 1,588-line form screen is already split into `form/` widgets and a controller.)
- [ ] Rework Home/Dashboard, Accounts and Reports once the budget screen sets the visual language.
- [ ] **Onboarding:** from install to the first budgeted euro in under 2 minutes.
- [x] **Localisation:** all strings in ARB, German complete, `de_DE` formats (audit package 6).
- [ ] Accessibility: contrast checks exist for the themes and chart palette, screen-reader labels on amounts and charts are done; still to do: a full TalkBack pass and 48dp touch targets everywhere.
- [ ] Semantic colours (income/expense/success/warning in `AppColors`) are fixed values; derive them from the theme so they keep contrast in dark and high-contrast mode.
- [ ] Empty, loading and error states on every screen (a shared `LoadErrorView` exists; not every screen uses it yet).

**Exit criteria:** every screen redesigned. Screenshots good enough for the Play Store. A new user can set up a budget without help.

## Phase 3: Ship (about 1–2 weeks)

- [ ] **Monetisation:** a free tier (e.g. 1 budget, 3 accounts or 100 transactions) plus a one-time "LedgerZero Pro" unlock via in-app purchase (`in_app_purchase` or RevenueCat). Add Restore Purchases and Family Sharing.
- [ ] Store setup: application IDs, release keystore and `android/key.properties`, Play Console listing in EN and DE, screenshots, and a short video.
- [ ] Privacy: Play data-safety form, a privacy-policy page, and a working support email/domain (`support@ledgerzero.app` is referenced; confirm you own it).
- [ ] Google OAuth consent screen verification for the Drive `drive.file` scope; Android OAuth clients for every app ID/signing key.
- [ ] Opt-in crash reporting or a "send diagnostic log" button (the local, opt-in error reporter exists).
- [ ] Closed beta with 10–20 testers (Play internal testing), recruited from r/ynab, r/Finanzen and r/personalfinance. Iterate for 1–2 weeks.
- [ ] Launch.

## Android-only, invisible encryption and Wi-Fi sync (2026-10)

- [x] v1 is Android only; iCloud sync and backup removed (ios/ kept for later).
- [x] Wi-Fi sync between paired phones (a household sharing one budget): QR pairing, signed local HTTP exchange of the encrypted change files, UDP discovery (docs/SYNC_ARCHITECTURE.md, "Local Wi-Fi").
- [x] No master password: the database key is kept by the Android KeyStore (flutter_secure_storage) and the database opens at every start, also behind the app lock. App lock = fingerprint/face/device PIN (BiometricPrompt), a UI gate; auto-lock locks only the UI. Older installs unlock once with the password, recovery key or biometrics and move the key (docs/ENCRYPTION.md). Sync and backups stay end-to-end encrypted.

## Follow-ups

**Real-device verification** (cannot be done on simulators/emulators)
- [ ] App lock on real phones: fingerprint, face and PIN/pattern prompts (Pixel 8, Xiaomi), auto-lock, and removing the screen lock turning the app lock off.
- [ ] One-time migration of the existing master-password installs on the Pixel 8 and the Xiaomi (take a backup first): unlock once, data intact, app lock on.
- [ ] FLAG_SECURE on Android.
- [ ] `flutter_secure_storage` v9 → v10 migration on a real Android install that has v9 data (then move to v11, which drops the migration).
- [ ] Argon2id time (46 MiB, 2 passes) for the sync passphrase and backup password on a mid-range Android phone stays under ~1.5 s.
- [ ] Two-device sync matrix with real accounts: Android↔Android (Drive); offline edits, deletes, double edits, new-device bootstrap, wrong passphrase.
- [ ] Wi-Fi sync on two real phones on a real home router: QR scan, discovery (routers that block broadcasts or client-to-client traffic), Xiaomi battery saver, merging the second phone's existing data.
- [ ] Notification delivery: scheduled-transaction reminders and sync-failure notifications on Android (permissions, exact vs. inexact alarms, tap routing).
- [ ] Card notification capture with real bank apps (Sparkasse, ING, DKB, N26, Revolut, Google Wallet, ...): collect anonymised notification texts, add them as parser test cases, and check that the listener survives reboots and vendor battery savers (Xiaomi/MIUI).

**Engineering**
- [ ] Riverpod 3 migration (app-wide; `flutter_riverpod` stays on 2.6).
- [ ] `google_sign_in` 7 (new authentication/authorization API, Android Credential Manager with a server client ID); needs real-device verification of Drive sign-in.
- [ ] `go_router` 18 together with the move to the unbundled `material_ui`/`cupertino_ui` packages.
- [ ] `csv` 7+ (rewritten parser); re-run all import fixtures.
- [ ] Third-party Android plugins still use deprecated Groovy DSL syntax (Gradle 10 will remove it) and `android.newDsl=false`; update when the plugins do.

**Product**
- [ ] Credit-card payment categories (YNAB-style handling of card spending and payments).
- [ ] Off-budget accounts, next step: import YNAB tracking accounts as off-budget accounts instead of skipping them (their on-budget transfer legs could then stay real transfers with YNAB's category).
- [ ] Goals UI (goal types and targets exist in the data model; the `underfunded` auto-assign rule and the budget row's underfunded icon wait for it).
- [ ] Double-import protection for the YNAB import (a second import of the same export duplicates all transactions; e.g. store YNAB ids / a file fingerprint and skip known rows).
- [ ] CSV import: skip preamble lines above the header, separate debit/credit columns, tab-delimited files.
- [ ] Accessibility: move keyboard/screen-reader focus to the first invalid field on validation errors (today `FormUtils.focusFirstError` only scrolls it into view, and only in the transaction and account forms).
- [x] Budget templates: save, apply and delete exist in the budget screen's month menu (renaming a template is not supported).
- [x] Card notification capture (Android): watched bank/card apps, encrypted queue until unlock, captured payments booked as unapproved transactions (docs/CARD_NOTIFICATIONS.md).
- [ ] Onboarding restarts from the "Your data, your device" slide when the POST_NOTIFICATIONS prompt appears right after the recovery-key step (seen twice on the Android 16 emulator, 2026-10-17; the third run, with the permission already granted, went through). The prompt itself is wrapped in `ExternalUiGuard`; the cause is not yet known (the router sends a locked mid-onboarding session back to `/onboarding`, so a lock or lost session is the first suspect).
- [ ] Bank CSV presets for the major German banks (Sparkasse, ING, DKB, N26, Comdirect).
- [ ] German keywords for the natural-language parser: only a handful of German category/income keywords and relative day words ("gestern", "heute", ...) exist; Chrono parses English date phrases only, and the keyword map only matches the seeded category names.

## In parallel: validate demand (start now)

- [ ] One-page landing site: "YNAB-style budgeting. Pay once. Your data never leaves your phone." Add an email waitlist.
- [ ] Post about it (not an ad, a "would you use this?") in r/ynab, r/Finanzen and r/selfhosted alternatives threads.
- [ ] Go/no-go signal before Phase 3: about 200+ waitlist sign-ups or strong qualitative pull. If it's silent, revisit positioning before spending time on store work.

## Later (v1.1+)

iOS app (the Flutter code and `ios/` project are kept; card notifications there would need an "Add transaction" App Intent for the Shortcuts Transaction automation, Apple Wallet, iOS 17+). Home-screen and lock-screen widgets (respecting privacy and app lock). macOS app. Shared household budgets.
