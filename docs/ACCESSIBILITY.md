# Accessibility Documentation

LedgerZero is committed to providing an accessible experience for all users. This document outlines the accessibility features implemented and guidelines for maintaining them.

## Implemented Features

### 1. Focus Indicators
- Interactive elements (buttons, inputs) have visible focus states.
- `BudgetCategoryRow` uses `InkWell` to provide visual feedback and focusability.
- Text fields have distinct borders when focused.

### 2. Screen Reader Support (ARIA-equivalent)
- Charts (`PieChart`, `SimpleBarChart`, `MultiLineChart`) are wrapped in `Semantics` widgets with descriptive labels summarizing the data (e.g., "Spending trend chart showing...").
- Images/Charts are marked as `image: true` for screen readers.
- `AppButton` loading states are announced as "Loading".
- `BudgetCategoryRow` provides a consolidated semantic label reading out "Category Name. Budgeted: $X. Activity: $Y. Available: $Z."

### 3. Error Handling
- Error messages in `ErrorView` utilize `Semantics(liveRegion: true)` to ensure immediate announcement by screen readers when they appear.
- Form validation errors automatically scroll to the first invalid field using `FormUtils.focusFirstError(context)` and trigger haptic feedback. (Note: Automatic focus movement requires explicit FocusNode management which is planned for a future update).

### 4. Navigation
- A "Skip to content" link is implemented at the top of the main shell (`ScaffoldWithNavBar`). It is visible when focused (via keyboard Tab) and allows bypassing the bottom navigation bar to jump directly to the main content area.

### 5. Color Contrast
- The application theme (`AppColors`) is tested against WCAG AA standards (4.5:1 minimum contrast ratio for normal text).
- Automated tests in `test/accessibility/color_contrast_test.dart` verify these ratios.

### 6. Reduced Motion
- Users can toggle "Reduced Motion" in Settings.
- Animations in charts and numeric counters (`AnimatedCountText`) respect this setting or the system-wide preference.

### 7. Haptic Feedback
- Critical actions (saving, errors, long-press) trigger haptic feedback to reinforce visual cues.

## Testing Guidelines

### Automated Tests
- Run color contrast tests: `flutter test test/accessibility/color_contrast_test.dart`
- Run accessibility audit tests: `flutter test test/accessibility/audit_test.dart`

### Manual Testing
- **Screen Reader:** Enable TalkBack (Android) or VoiceOver (iOS) and navigate through the app. Verify that all interactive elements are reachable and labeled correctly.
- **Keyboard:** Connect a bluetooth keyboard and navigate using Tab/Arrow keys. Verify focus indicators are visible and logical.
- **Settings:** Toggle "Reduced Motion" and verify animations are disabled.

## Future Improvements
- Dynamic Type support (font scaling) audit.
- High Contrast theme refinements.
