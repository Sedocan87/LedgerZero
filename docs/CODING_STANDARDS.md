# Coding Standards

Rules for code in `lib/`. The architecture is described in
[REPOSITORY_PATTERN.md](../REPOSITORY_PATTERN.md); UI conventions in
[STYLE_GUIDE.md](STYLE_GUIDE.md).

## Quality gate

Run before every commit:

```bash
bash tool/check.sh          # gen-l10n check, flutter analyze, flutter test
bash tool/check.sh --perf   # additionally the perf-tagged tests
```

`flutter analyze` must be clean. The lint set is in `analysis_options.yaml`
(on top of `flutter_lints`): among others `always_use_package_imports`,
`prefer_single_quotes`, `prefer_const_constructors`, `prefer_final_locals`,
`always_put_control_body_on_new_line`, `curly_braces_in_flow_control_structures`,
`unawaited_futures`, `use_build_context_synchronously`.

## Layers

* `lib/presentation` works through providers, domain services and
  repositories; DAOs and `AppDatabase` are only touched in the provider
  wiring (`lib/presentation/providers/`) and in sync/backup services.
  Screens never import `lib/data/database/database.dart` for Drift row
  types; providers map rows to view models (e.g. the sync controller maps
  `sync_conflicts` / `sync_quarantine` rows to `SyncConflictItem` /
  `SyncQuarantineItem`).
* `lib/domain` has no Flutter UI or Drift imports in entities and
  repository interfaces.
* Writes that touch more than one row go through a domain service inside a
  `UnitOfWork`. Transactions are only written through `TransactionService`.
* State management is `flutter_riverpod` 2.x; navigation is `go_router`
  (routes in `lib/presentation/router/app_router.dart`). Use named routes.

## Money

* Every amount is an `int` of minor units (hundredths) for every currency,
  JPY included (stored x100, displayed with 0 decimals).
* Use `Money` (`lib/core/money/money.dart`) for arithmetic helpers
  (`Money.sum`, `Money.divideRounded`, `Money.fromMajor`) and `MoneyParser`
  for parsing text. Doubles only at the display edge (chart coordinates,
  percentages).
* Never store a derived amount (balance, available, TBB); compute it.

## Dates

* Every `DateTime` written to the database or a sync payload is UTC.
* Date-only values are calendar days stored as UTC midnight of the picked
  day: use `CalendarDate.fromLocalPick` / `normalize` /
  `today()` (`lib/core/time/calendar_date.dart`). Read their
  `year`/`month`/`day`; never call `toLocal()` on them.
* Month and range queries use half-open intervals
  `[CalendarDate.startOfMonthUtc(m), CalendarDate.endOfMonthUtc(m))`;
  month keys are `CalendarDate.monthKey` (`yyyy-MM`).

## IDs

* New rows: UUID v4.
* Rows that two devices may create independently use deterministic UUIDv5
  ids from `DeterministicId` (`lib/core/constants/deterministic_id.dart`):
  budget rows, seeded default groups and categories, scheduled occurrences.

## Text and formatting

* No hard-coded user-visible strings. Add every string to both
  `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` and use
  `AppLocalizations.of(context)!.key`. `test/l10n/hardcoded_text_guard_test.dart`
  and `test/l10n/arb_completeness_test.dart` enforce this; `tool/check.sh`
  fails on untranslated messages or stale generated files.
* Labels for enums live in `lib/presentation/l10n/enum_labels.dart`.
* Format amounts and dates only through `appFormatterProvider`
  (`AppFormatter`), which honours the currency, language, number format and
  date format settings. Do not create `NumberFormat` / `DateFormat`
  instances in widgets for user-visible values (file-name stamps and
  parsing of machine formats are fine).
* Machine formats (CSV export headers, backup files) stay English.

## Errors and logging

* Use `Logger` (`lib/core/utils/logger.dart`), not `print`. Logging is off
  in release builds.
* Repositories wrap database errors in `DatabaseException`.
* Screens show a localised message (`LoadErrorView`, `ErrorView`,
  snackbars), never `e.toString()`.
* Never log secrets, keys, passwords or full transaction details.

## Tests

New logic gets unit tests; database behaviour is tested against an
in-memory database (`test/helpers/test_database.dart`). See
[TESTING.md](TESTING.md).
