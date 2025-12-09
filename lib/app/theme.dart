import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';

class AppColors {
  // Light Mode Colors
  static const Color primaryLight = Color(0xFF00796B); // Teal 700
  static const Color onPrimaryLight = Colors.white;
  static const Color primaryContainerLight =
      Color(0xFFB2DFDB); // Teal 100 for containers
  static const Color onPrimaryContainerLight = Color(0xFF004D40); // Teal 900

  static const Color secondaryLight = Color(0xFF455A64); // Blue Grey 700
  static const Color onSecondaryLight = Colors.white;
  static const Color secondaryContainerLight = Color(0xFFCFD8DC);
  static const Color onSecondaryContainerLight = Color(0xFF263238);

  static const Color tertiaryLight = Color(0xFFFFA000); // Amber 700
  static const Color onTertiaryLight = Colors.black;

  static const Color errorLight = Color(0xFFB00020);
  static const Color onErrorLight = Colors.white;

  static const Color backgroundLight = Color(0xFFF5F5F5); // Grey 100
  static const Color surfaceLight = Colors.white;
  static const Color onSurfaceLight = Colors.black;

  // Dark Mode Colors
  static const Color primaryDark = Color(0xFF80CBC4); // Teal 200
  static const Color onPrimaryDark = Color(0xFF004D40); // Teal 900
  static const Color primaryContainerDark = Color(0xFF00695C); // Teal 800
  static const Color onPrimaryContainerDark = Color(0xFFB2DFDB); // Teal 100

  static const Color secondaryDark = Color(0xFFB0BEC5); // Blue Grey 200
  static const Color onSecondaryDark = Color(0xFF263238); // Blue Grey 900
  static const Color secondaryContainerDark = Color(0xFF37474F); // Blue Grey 800
  static const Color onSecondaryContainerDark = Color(0xFFCFD8DC); // Blue Grey 100

  static const Color tertiaryDark = Color(0xFFFFE082); // Amber 200
  static const Color onTertiaryDark = Colors.black;

  static const Color errorDark = Color(0xFFCF6679);
  static const Color onErrorDark = Colors.black;

  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color onSurfaceDark = Color(0xFFE0E0E0);

  // High Contrast Light
  static const Color highContrastPrimaryLight = Color(0xFF004D40); // Teal 900
  static const Color highContrastOnPrimaryLight = Colors.white;
  static const Color highContrastBackgroundLight = Colors.white;
  static const Color highContrastSurfaceLight = Colors.white;
  static const Color highContrastOnSurfaceLight = Colors.black;

  // High Contrast Dark
  static const Color highContrastPrimaryDark = Color(0xFF80CBC4); // Teal 200
  static const Color highContrastOnPrimaryDark = Colors.black;
  static const Color highContrastBackgroundDark = Colors.black;
  static const Color highContrastSurfaceDark = Colors.black;
  static const Color highContrastOnSurfaceDark = Colors.white;

  // Semantic Colors (Shared)
  static const Color income = Color(0xFF4CAF50); // Green 500
  static const Color expense = Color(0xFFB00020); // Red 700
  static const Color success = Color(0xFF4CAF50); // Green 500
  static const Color warning = Color(0xFFFFC107); // Amber 500
  static const Color error = Color(0xFFB00020); // Red 700
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );
}

class AppTheme {
  static final ThemeData lightTheme = _buildTheme(
    brightness: Brightness.light,
    primary: AppColors.primaryLight,
    onPrimary: AppColors.onPrimaryLight,
    primaryContainer: AppColors.primaryContainerLight,
    onPrimaryContainer: AppColors.onPrimaryContainerLight,
    secondary: AppColors.secondaryLight,
    onSecondary: AppColors.onSecondaryLight,
    secondaryContainer: AppColors.secondaryContainerLight,
    onSecondaryContainer: AppColors.onSecondaryContainerLight,
    tertiary: AppColors.tertiaryLight,
    onTertiary: AppColors.onTertiaryLight,
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.onSurfaceLight,
  );

  static final ThemeData darkTheme = _buildTheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryDark,
    onPrimary: AppColors.onPrimaryDark,
    primaryContainer: AppColors.primaryContainerDark,
    onPrimaryContainer: AppColors.onPrimaryContainerDark,
    secondary: AppColors.secondaryDark,
    onSecondary: AppColors.onSecondaryDark,
    secondaryContainer: AppColors.secondaryContainerDark,
    onSecondaryContainer: AppColors.onSecondaryContainerDark,
    tertiary: AppColors.tertiaryDark,
    onTertiary: AppColors.onTertiaryDark,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurfaceDark,
  );

  static final ThemeData highContrastLightTheme = _buildTheme(
    brightness: Brightness.light,
    primary: AppColors.highContrastPrimaryLight,
    onPrimary: AppColors.highContrastOnPrimaryLight,
    background: AppColors.highContrastBackgroundLight,
    surface: AppColors.highContrastSurfaceLight,
    onSurface: AppColors.highContrastOnSurfaceLight,
    isHighContrast: true,
  );

  static final ThemeData highContrastDarkTheme = _buildTheme(
    brightness: Brightness.dark,
    primary: AppColors.highContrastPrimaryDark,
    onPrimary: AppColors.highContrastOnPrimaryDark,
    background: AppColors.highContrastBackgroundDark,
    surface: AppColors.highContrastSurfaceDark,
    onSurface: AppColors.highContrastOnSurfaceDark,
    isHighContrast: true,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color background,
    required Color surface,
    required Color onSurface,
    // Optional params for restoring standard theme colors
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    bool isHighContrast = false,
  }) {
    final base = brightness == Brightness.light ? ThemeData.light() : ThemeData.dark();

    // Default fallback logic if not provided (similar to high contrast simplifications)
    final effectiveSecondary = secondary ?? primary;
    final effectiveOnSecondary = onSecondary ?? onPrimary;

    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: effectiveSecondary,
        onSecondary: effectiveOnSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        error: brightness == Brightness.light ? AppColors.errorLight : AppColors.errorDark,
        onError: brightness == Brightness.light ? AppColors.onErrorLight : AppColors.onErrorDark,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.heading1,
        headlineMedium: AppTextStyles.heading2,
        bodyLarge: AppTextStyles.body,
        labelSmall: AppTextStyles.caption,
      ).apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isHighContrast ? background : primary,
        foregroundColor: isHighContrast ? onSurface : onPrimary,
        centerTitle: true,
        elevation: isHighContrast ? 4 : 0, // More distinction in HC
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: AppElevation.sm,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: isHighContrast ? BorderSide(color: onSurface, width: 2) : BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(48, 48), // Accessibility Minimum Touch Target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: isHighContrast ? 2 : 1),
          minimumSize: const Size(48, 48), // Accessibility Minimum Touch Target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48), // Accessibility Minimum Touch Target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isHighContrast ? background : (brightness == Brightness.light ? const Color(0xFFEEEEEE) : const Color(0xFF212121)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: isHighContrast ? BorderSide(color: onSurface) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        enabledBorder: isHighContrast ? OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: onSurface, width: 1),
        ) : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
