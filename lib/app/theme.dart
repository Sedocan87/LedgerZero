import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';

class AppColors {
  // We use a modern Teal seed color for a financial/safe yet vibrant look.
  static const Color seedColor = Color(0xFF009688); // Vibrant Teal

  // Fixed semantic colours, tuned for the light theme. Screens should use
  // the theme-aware ones instead (`AppSemanticColors.of(context)`), which
  // keep 4.5:1 text contrast in light and dark.
  static const Color income = Color(0xFF2E7D32); // Green 800
  static const Color expense = Color(0xFFC62828); // Red 800
  static const Color success = Color(0xFF2E7D32); // Same as income/success
  static const Color warning = Color(0xFFF57C00); // Orange 700
  static const Color error = Color(0xFFBA1A1A); // M3 Error
}

/// The colours that carry meaning (state), for the active theme: light and
/// dark values that keep at least 4.5:1 text contrast on `surface`,
/// `surfaceContainerLow` and on their own [tonal] pill
/// (`test/app/theme_test.dart`).
///
/// Colour carries state only (docs/STYLE_GUIDE.md, "Colour roles"): amounts
/// are drawn in `onSurface`; [success] marks money available and inflows,
/// [error] cash overspending, [warning] credit overspending. [income] and
/// [expense] are kept for charts and legends that need a pair.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.income,
    required this.expense,
    required this.success,
    required this.warning,
    required this.error,
  });

  /// The semantic colours for [scheme] (its brightness picks the values).
  factory AppSemanticColors.fromScheme(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    final success = light ? const Color(0xFF1B6E20) : const Color(0xFF81C784);
    return AppSemanticColors(
      income: success,
      expense: light ? const Color(0xFFA8201A) : const Color(0xFFEF9A9A),
      success: success,
      warning: light ? const Color(0xFF8A4500) : const Color(0xFFFFB74D),
      error: scheme.error,
    );
  }

  final Color income;
  final Color expense;
  final Color success;
  final Color warning;
  final Color error;

  /// The theme's semantic colours; a theme without the extension (a test's
  /// plain `ThemeData`) gets the values for its colour scheme.
  static AppSemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppSemanticColors>() ??
        AppSemanticColors.fromScheme(theme.colorScheme);
  }

  /// Opacity of [color] in a [tonal] fill.
  static const double tonalAlpha = 0.14;

  /// A faint fill of [color] over [background], for a status pill or chip
  /// whose text is drawn in [color].
  static Color tonal(Color color, Color background) =>
      Color.alphaBlend(color.withValues(alpha: tonalAlpha), background);

  @override
  AppSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? success,
    Color? warning,
    Color? error,
  }) => AppSemanticColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
  );

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppSemanticColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

/// Tabular (fixed-width) figures, so the digits of amounts in a column line
/// up: `theme.textTheme.bodyMedium?.tabular`. Every money amount uses it.
extension TabularFigures on TextStyle {
  TextStyle get tabular {
    final features = fontFeatures ?? const <FontFeature>[];
    if (features.contains(const FontFeature.tabularFigures())) {
      return this;
    }
    return copyWith(
      fontFeatures: [...features, const FontFeature.tabularFigures()],
    );
  }
}

/// The app's type scale. Every style is Inter (bundled under
/// `assets/fonts/Inter/`, declared in pubspec.yaml): headlines and titles
/// 600–700, body 400, labels 500. PDF reports keep Roboto.
class AppTextStyles {
  /// The family of all app text.
  static const String fontFamily = 'Inter';

  // Material 3 Typography Scale Mapping — Refined for modern fintech clarity
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.16,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.22,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.28,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.33,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.33,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.33,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.45,
  );
}

class AppTheme {
  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static final ThemeData highContrastLightTheme = _buildTheme(
    Brightness.light,
    isHighContrast: true,
  );
  static final ThemeData highContrastDarkTheme = _buildTheme(
    Brightness.dark,
    isHighContrast: true,
  );

  static ThemeData _buildTheme(
    Brightness brightness, {
    bool isHighContrast = false,
  }) {
    // Generate harmonious color scheme from seed
    ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seedColor,
      brightness: brightness,
      dynamicSchemeVariant:
          DynamicSchemeVariant.fidelity, // Vibrant but faithful
    );

    if (isHighContrast) {
      // Very basic high contrast overwrite if needed, or rely on system
      colorScheme = colorScheme.copyWith(
        primary: brightness == Brightness.light ? Colors.black : Colors.white,
        onPrimary: brightness == Brightness.light ? Colors.white : Colors.black,
        surface: brightness == Brightness.light ? Colors.white : Colors.black,
        onSurface: brightness == Brightness.light ? Colors.black : Colors.white,
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      // Also covers the styles built from the type scale below.
      fontFamily: AppTextStyles.fontFamily,
      extensions: [
        ChartPalette.fromScheme(colorScheme, highContrast: isHighContrast),
        AppSemanticColors.fromScheme(colorScheme),
      ],

      textTheme:
          const TextTheme(
            displayLarge: AppTextStyles.displayLarge,
            displayMedium: AppTextStyles.displayMedium,
            displaySmall: AppTextStyles.displaySmall,
            headlineLarge: AppTextStyles.headlineLarge,
            headlineMedium: AppTextStyles.headlineMedium,
            headlineSmall: AppTextStyles.headlineSmall,
            titleLarge: AppTextStyles.titleLarge,
            titleMedium: AppTextStyles.titleMedium,
            titleSmall: AppTextStyles.titleSmall,
            bodyLarge: AppTextStyles.bodyLarge,
            bodyMedium: AppTextStyles.bodyMedium,
            bodySmall: AppTextStyles.bodySmall,
            labelLarge: AppTextStyles.labelLarge,
            labelMedium: AppTextStyles.labelMedium,
            labelSmall: AppTextStyles.labelSmall,
          ).apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),

      scaffoldBackgroundColor: colorScheme.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),

      // Tonal cards: a fill one step above the page, no outline (outlines
      // are kept for text inputs and outlined buttons).
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: colorScheme.onPrimaryContainer,
              size: 24,
            );
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            // 11 sp, no extra tracking: Inter is wider than Roboto, and
            // "Transactions" must fit a fifth of a 360 dp phone.
            return AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: colorScheme.onSurface,
            );
          }
          return AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 3,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),

      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
    );
  }
}
