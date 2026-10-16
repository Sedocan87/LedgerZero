# LedgerZero

LedgerZero is a local-first envelope budgeting app (zero-based, YNAB-style)
for iOS and Android, in English and German. All data lives in an encrypted
database on the phone; sync and backups go to the user's own Google Drive or
iCloud Drive, end-to-end encrypted. No account, no server. It is planned as a
one-time purchase (see [ROADMAP.md](ROADMAP.md)). Version 0.1.0, not
released yet.

## Features

- Accounts, envelope budget with To Be Budgeted, monthly assignment and
  moving money between categories (with undo), budget templates. (Category
  goals exist in the data model but cannot be set in the app yet.)
- Transactions with transfers, splits, cleared/reconciled state, undo/redo,
  search; scheduled (recurring) transactions with reminders.
- Quick add from a sentence ("12.50 bakery yesterday") with a rule-based,
  on-device parser; rules that set payee/category on new transactions.
- Reports (spending, trends, income vs. expense, net worth, budget vs.
  actual) with CSV/PDF export.
- Import from CSV (saved column mappings) and YNAB; CSV export.
- Master password, recovery key, optional biometric unlock, auto-lock,
  app-switcher privacy cover.
- Encrypted backup/restore and encrypted multi-device sync via Google Drive
  or iCloud Drive.

## Architecture

```
presentation  Riverpod 2 providers, go_router, screens and widgets
    |
domain        entities, repository interfaces, services (TransactionService,
    |         BudgetingService, ...), undo, use cases
    |
data          Drift database (SQLCipher), DAOs, repository implementations
services      backup, sync, security, import/export, NLP, notifications, reports
core          money, calendar dates, formatting helpers, constants, errors
```

- **Database:** [Drift](https://drift.simonbinder.eu/) on SQLCipher (the
  `sqlite3` package's build hook bundles SQLCipher, see `hooks:` in
  `pubspec.yaml`). Schema version 18; see [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md)
  and [REPOSITORY_PATTERN.md](REPOSITORY_PATTERN.md).
- **Money** is always an `int` of minor units (hundredths) for every
  currency; doubles exist only for chart coordinates and percentages
  (`lib/core/money/`). Balances, activity and To Be Budgeted are computed,
  never stored ([docs/BUDGETING_RULES.md](docs/BUDGETING_RULES.md)).
- **Dates** are stored in UTC; date-only values are UTC midnight of the
  calendar day the user picked (`lib/core/time/`).
- **Key vault:** a random 256-bit data key encrypts the database (raw hex
  SQLCipher key). It is stored only wrapped (AES-256-GCM): by a key derived
  from the master password (Argon2id), by a recovery key shown at
  onboarding, and optionally by a hardware-bound biometric key. Without a
  key the database does not open. See [docs/ENCRYPTION.md](docs/ENCRYPTION.md)
  and [docs/SECURITY.md](docs/SECURITY.md).
- **Sync v2:** each sync run uploads one AES-256-GCM encrypted change file
  to the user's Google Drive (`drive.file` scope) or iCloud Drive; the key
  comes from a separate sync passphrase. Rows merge last-writer-wins by
  their UTC `updated_at`; new devices bootstrap from an encrypted snapshot.
  See [docs/SYNC_ARCHITECTURE.md](docs/SYNC_ARCHITECTURE.md) and
  [docs/DELTA_FORMAT.md](docs/DELTA_FORMAT.md).
- **Backups (format v2)** are always encrypted, locally or to the cloud.
  See [docs/BACKUP_FORMAT.md](docs/BACKUP_FORMAT.md) and
  [docs/BACKUP_AND_EXPORT.md](docs/BACKUP_AND_EXPORT.md).
- **Localisation:** ARB files in `lib/l10n/` (`app_en.arb`, `app_de.arb`),
  generated with `flutter gen-l10n`; amounts and dates follow the user's
  currency, locale and format settings.

## Getting started

Requirements: Flutter 3.47 (Dart 3.13), Xcode with an iOS 15+ simulator,
Android SDK 36 with JDK 17 (Android Studio's bundled JBR works).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after changing tables, DAOs or mocks
bash tool/check.sh                                         # l10n check, analyze, unit + widget tests
```

### Running

Android has three flavors (`development`, `staging`, `production`; app IDs
`com.ledgerzero.app.dev`, `.staging` and `com.ledgerzero.app`), each with its
own entry point. iOS has no flavors; pass the entry point.

```bash
flutter run --flavor development -t lib/main_development.dart -d <android-device>
flutter run -t lib/main_development.dart -d <ios-simulator>
```

Release builds:

```bash
flutter build apk --release --flavor production -t lib/main_production.dart
flutter build ios --release -t lib/main_production.dart
```

Android release signing reads `android/key.properties` (`storeFile`,
`storePassword`, `keyAlias`, `keyPassword`; git-ignored, never commit it or
the keystore). Without that file release builds are signed with the debug
key so they still build locally; such APKs cannot be uploaded to Play.

### Google Drive sign-in

- iOS: create `ios/Flutter/GoogleSignIn.xcconfig` (git-ignored) with your
  iOS OAuth client ID. Without it the app builds and runs, but Google Drive
  sync reports "not configured".
- Android: register an Android OAuth client for each application ID and
  signing certificate (SHA-1) you use.

Details: [docs/GOOGLE_DRIVE_SETUP.md](docs/GOOGLE_DRIVE_SETUP.md). iCloud
needs the `iCloud.com.ledgerzero.app` container on your Apple developer
account: [docs/ICLOUD_SETUP.md](docs/ICLOUD_SETUP.md).

### Tests

- `bash tool/check.sh`: generated localisations up to date and complete,
  `flutter analyze` (0 issues), all unit and widget tests (`--perf` adds the
  timing tests).
- Integration tests run on an iOS Simulator or Android emulator only (they
  wipe the app's data): see [docs/TESTING.md](docs/TESTING.md).

## Project structure

```
lib/
  app/            MaterialApp, theme (incl. chart palette)
  core/           config, constants, errors, money, time, providers, utils
  data/           database (tables, DAOs, migrations), models, repositories
  domain/         entities, repository interfaces, services, undo, use cases
  l10n/           ARB files and generated localisations
  presentation/   providers, router, screens, widgets
  services/       backup, csv, error, export, import, nlp, notifications,
                  reports, rules, security, sync
  main*.dart      entry points (development, staging, production)
test/             unit and widget tests
integration_test/ on-device tests (simulator/emulator)
drift_schemas/    exported schema per version (migration tests)
tool/             check.sh, schema helper post-processing
docs/             design and user documentation
```

## Documentation

| Topic | Document |
|---|---|
| Budget maths, To Be Budgeted | [docs/BUDGETING_RULES.md](docs/BUDGETING_RULES.md), [docs/BUDGET_INTERACTIONS.md](docs/BUDGET_INTERACTIONS.md) |
| Transactions, scheduled transactions, payees, rules | [docs/TRANSACTION_LIFECYCLE.md](docs/TRANSACTION_LIFECYCLE.md), [docs/SCHEDULED_TRANSACTIONS.md](docs/SCHEDULED_TRANSACTIONS.md), [docs/PAYEE_MANAGEMENT.md](docs/PAYEE_MANAGEMENT.md), [docs/RULES.md](docs/RULES.md) |
| Quick add parser | [docs/NATURAL_LANGUAGE_FORMATS.md](docs/NATURAL_LANGUAGE_FORMATS.md) |
| Encryption and security | [docs/ENCRYPTION.md](docs/ENCRYPTION.md), [docs/SECURITY.md](docs/SECURITY.md), [docs/ENCRYPTION_TROUBLESHOOTING.md](docs/ENCRYPTION_TROUBLESHOOTING.md) |
| Sync | [docs/SYNC_ARCHITECTURE.md](docs/SYNC_ARCHITECTURE.md), [docs/DELTA_FORMAT.md](docs/DELTA_FORMAT.md), [docs/DELTA_SCHEMA_MIGRATION.md](docs/DELTA_SCHEMA_MIGRATION.md), [docs/GOOGLE_DRIVE_SETUP.md](docs/GOOGLE_DRIVE_SETUP.md), [docs/ICLOUD_SETUP.md](docs/ICLOUD_SETUP.md), [docs/ICLOUD_TROUBLESHOOTING.md](docs/ICLOUD_TROUBLESHOOTING.md), [docs/OFFLINE_CAPABILITIES.md](docs/OFFLINE_CAPABILITIES.md) |
| Backup, import, export | [docs/BACKUP_AND_EXPORT.md](docs/BACKUP_AND_EXPORT.md), [docs/BACKUP_FORMAT.md](docs/BACKUP_FORMAT.md), [docs/CSV_FORMAT.md](docs/CSV_FORMAT.md), [docs/YNAB_MIGRATION.md](docs/YNAB_MIGRATION.md) |
| Platform notes, errors | [docs/PLATFORM_SPECIFICS.md](docs/PLATFORM_SPECIFICS.md), [docs/ERROR_RECOVERY.md](docs/ERROR_RECOVERY.md), [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| Code and tests | [docs/CODING_STANDARDS.md](docs/CODING_STANDARDS.md), [docs/STYLE_GUIDE.md](docs/STYLE_GUIDE.md), [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md), [docs/TESTING.md](docs/TESTING.md), [docs/PERFORMANCE.md](docs/PERFORMANCE.md) |
| Plan | [ROADMAP.md](ROADMAP.md) |
