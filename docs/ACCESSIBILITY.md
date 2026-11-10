# Accessibility

What the app does for screen readers, keyboard users, contrast and motion,
and how it is tested.

## Settings

* **Reduced Motion**: switch in Settings (General section). Stored in
  `ThemeState.reducedMotion`. Animations are also off when the platform asks
  for it (`MediaQuery.disableAnimations`).
* **High contrast**: Settings > Accessibility. Switches to
  `AppTheme.highContrastLightTheme` / `highContrastDarkTheme` (black/white
  primary and surface; the chart palette raises its contrast too). The
  platform's high-contrast setting is not followed automatically.

To check whether animations may run, call `animationsEnabled(context, ref)`
in `build` (rebuilds when the setting changes), `animationsEnabledOf(context)`
where there is no `WidgetRef` (page transitions), or
`ThemeNotifier.shouldAnimate` for a one-off check
(`lib/presentation/providers/theme_provider.dart`). Page transitions in the
router and the tutorial overlay use them.
Charts are drawn without animation.

## Screen readers

* Charts (`PieChart`, `SimpleBarChart`, `MultiLineChart`,
  `BalanceTrendChart`, `BudgetVsActualChart`) expose one localised summary
  label and exclude their painted children.
* `AmountText` adds the meaning of an amount to its label via
  `AmountContext` (budgeted, activity, available / overspent, To Be
  Budgeted), so a screen reader does not just read a bare number.
* In the budget's comparison view the progress text reads as
  "spent of budgeted"; the underfunded goal icon has a label (it only
  appears once goals can be set, which the app does not offer yet).
* `AppButton` announces its loading state ("<label>, Loading").
* `ErrorView` and `LoadErrorView` use `Semantics(liveRegion: true)` so
  errors are announced when they appear.
* All labels come from the ARB files (EN/DE).

## Keyboard and focus

* The tab shell (`ScaffoldWithNavBar`) has a "Skip to content" button that
  appears when it receives focus and moves focus to the tab content.
* `FormUtils.focusFirstError(context)` (used by the transaction and account
  forms) gives haptic feedback and scrolls the first invalid field into
  view. It does not move keyboard focus to that field.
* Amount cells, the month chevrons and the clear-status button are at
  least `kMinInteractiveDimension` (48 dp) tall. A budget category row is
  56 dp; its budgeted amount is plain text with a 48 dp tap target.

## Colour

* Colour schemes are generated from the teal seed with
  `ColorScheme.fromSeed`; `test/app/theme_test.dart` checks that
  onPrimary/primary, onPrimaryContainer/primaryContainer, onSurface/surface
  and onError/error reach WCAG AA (4.5:1) in every theme, and that the
  semantic colours (`AppSemanticColors`: success, warning, error, income,
  expense) keep 4.5:1 on `surface`, `surfaceContainerLow` and their own
  tonal pill in light, dark and high contrast.
* State is not told by colour alone: To Be Budgeted has a status chip
  ("Ready to assign", "Overassigned", "All assigned"), and an amount's
  screen-reader label says "available" / "overspent" /
  "overbudgeted".
* `ChartPalette` (theme extension) keeps chart colours at least 3:1 against
  the surface (4.5:1 in high contrast); see
  `test/presentation/widgets/charts/chart_palette_test.dart`.

## Haptics

A light impact on `AppButton` presses, a selection click whenever a budget
amount is set on the budget screen, and a heavy impact when
form validation fails (`FormUtils.focusFirstError`).

## Tests

* `test/accessibility/semantics_test.dart`: chart summaries, AppButton
  semantics, 48x48 clear-status button.
* `test/accessibility/audit_test.dart`: tap-target and text-contrast
  guidelines for `AppButton`.
* `test/presentation/accessibility_test.dart`: Flutter accessibility
  guidelines on the home screen.
* `test/app/theme_test.dart`: theme contrast.

Manual checks before a release: TalkBack (Android) and VoiceOver (iOS)
through the main tabs and forms; a hardware keyboard (Tab, arrows); the
largest system font size; Reduced Motion on.

## Known gaps

* No audit of large font sizes (text scaling) yet, beyond the budget row
  (`budget_row_fit_test.dart`: text scale 1.3 at 360 dp, where the name
  moves to its own line).
* Form validation does not move focus to the first invalid field.
* The high-contrast theme only overrides primary and surface colours.
