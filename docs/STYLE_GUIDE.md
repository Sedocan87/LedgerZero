# LedgerZero Design System Style Guide

This document outlines the design system standards and reusable components for LedgerZero.

## Typography

Text styles are defined in `AppTextStyles` and mapped to `ThemeData.textTheme`.
- **Display Large**: Headings (`AppTextStyles.heading1`)
- **Headline Medium**: Subheadings (`AppTextStyles.heading2`)
- **Body Large**: Regular text (`AppTextStyles.body`)
- **Label Small**: Captions (`AppTextStyles.caption`)

Usage:
```dart
Text('Hello', style: Theme.of(context).textTheme.headlineMedium);
```

## Colors

Colors are defined in `AppColors` and mapped to `ThemeData.colorScheme`.
- **Primary**: Teal
- **Secondary**: Blue Grey
- **Tertiary**: Amber
- **Error**: Red

## Dimensions & Spacing

Use constants from `lib/core/constants/dimensions.dart`.
- **Spacing**: `AppSpacing.xs` to `AppSpacing.xxl`
- **Radius**: `AppRadius.xs` to `AppRadius.xxl`
- **Elevation**: `AppElevation.none` to `AppElevation.xl`

## Components

### Buttons
Use `AppButton` from `lib/presentation/widgets/common/buttons.dart`.
- `AppButton.primary(...)`
- `AppButton.secondary(...)`
- `AppButton.text(...)`

### Input Fields
Use `AppTextField` from `lib/presentation/widgets/common/app_text_field.dart`.

### Cards
Use `AppCard` from `lib/presentation/widgets/common/app_card.dart`.

### App Bar
Use `LedgerAppBar` from `lib/presentation/widgets/common/app_bar.dart`.

### Loading Indicator
Use `LoadingIndicator` from `lib/presentation/widgets/common/loading_indicator.dart`. It adapts to platform.

### Feedback
- **Error**: `ErrorView`
- **Success**: `SuccessView`
- **Empty State**: `EmptyState`

### Icons
Use `AppIcons` from `lib/core/constants/app_icons.dart`.

## Platform Adaptation
Use `PlatformWidget` abstract class to build platform-specific UI (Material/Cupertino).
