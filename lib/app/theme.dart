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
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    textTheme: const TextTheme(
      displayLarge: AppTextStyles.heading1,
      headlineMedium: AppTextStyles.heading2,
      bodyLarge: AppTextStyles.body,
      labelSmall: AppTextStyles.caption,
    ).apply(
      bodyColor: AppColors.onSurfaceLight,
      displayColor: AppColors.onSurfaceLight,
    ),
    colorScheme: const ColorScheme.light(
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
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
    ),
    scaffoldBackgroundColor: AppColors.backgroundLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.onPrimaryLight,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    textTheme: const TextTheme(
      displayLarge: AppTextStyles.heading1,
      headlineMedium: AppTextStyles.heading2,
      bodyLarge: AppTextStyles.body,
      labelSmall: AppTextStyles.caption,
    ).apply(
      bodyColor: AppColors.onSurfaceDark,
      displayColor: AppColors.onSurfaceDark,
    ),
    colorScheme: const ColorScheme.dark(
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
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: AppColors.onSurfaceDark,
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
  );
}
