# Style Guide

UI building blocks and conventions. Material 3 only (no separate Cupertino
UI), iOS and Android.

## Theme

`lib/app/theme.dart`:

* `AppTheme.lightTheme`, `darkTheme`, `highContrastLightTheme`,
  `highContrastDarkTheme`. The colour scheme is generated with
  `ColorScheme.fromSeed` from `AppColors.seedColor` (teal,
  `DynamicSchemeVariant.fidelity`). High contrast overrides primary and
  surface with black/white.
* Use `Theme.of(context).colorScheme` for colours. `AppColors` also defines
  semantic colours (`income`, `expense`, `success`, `warning`, `error`).
* Text: use `Theme.of(context).textTheme` (`displayLarge` ... `labelSmall`);
  the styles come from `AppTextStyles`.
* Charts take their colours from the `ChartPalette` theme extension
  (`ChartPalette.of(context)`,
  `lib/presentation/widgets/charts/chart_palette.dart`): categorical colours
  for slices plus income, expense, net worth, bar, budgeted and spent. It
  follows light, dark and high contrast. Do not hard-code chart colours.

## Spacing and shape

`lib/core/constants/dimensions.dart`:

* `AppSpacing`: `xs` 4, `sm` 8, `md` 16, `lg` 24, `xl` 32, `xxl` 48.
* `AppRadius`: `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `xxl` 32,
  `full` 100.

Interactive targets are at least `kMinInteractiveDimension` (48 dp).

## Icons

`AppIcons` (`lib/core/constants/app_icons.dart`) maps app concepts to
Material icons; prefer it over `Icons.*` for concepts it covers.

## Common widgets (`lib/presentation/widgets/common/`)

| Widget | Use |
| --- | --- |
| `AppButton.primary` / `.secondary` / `.text` | Buttons with optional icon and `isLoading` (disables and announces loading). |
| `AppTextField` | Text inputs. |
| `AppCard` | Card container. |
| `AppLoadingIndicator` | Centred progress indicator (Cupertino style on iOS). |
| `AmountText` | Any money amount: formats via `appFormatterProvider` and adds screen-reader wording through `AmountContext`. |
| `LoadErrorView` | Error state of a screen or section (`compact: true` for a one-line version); localised message, optional retry, logs details. |
| `ErrorView` | Full-screen error with a live-region announcement (used by `LoadErrorView`). |
| `EmptyState` | Empty list/screen with title, description, optional icon and action. |
| `OfflineIndicator` | Connectivity banner in the tab shell. |

Other shared widgets: pickers in `lib/presentation/widgets/pickers/`
(account, category, payee), recurrence selector in
`lib/presentation/widgets/recurrence/`, charts in
`lib/presentation/widgets/charts/`.

Screens use a plain Material `AppBar`; there is no app-specific app bar
widget.

## Text and numbers

* All user-visible text comes from `AppLocalizations` (EN/DE); see
  [CODING_STANDARDS.md](CODING_STANDARDS.md).
* Amounts and dates are formatted only through `appFormatterProvider`.
* German strings are often longer: check layouts in German
  (`test/l10n/german_layout_smoke_test.dart`).

## Motion

Gate animations with `animationsEnabled(context, ref)` so Reduced Motion and
the platform setting are respected; see [ACCESSIBILITY.md](ACCESSIBILITY.md).
