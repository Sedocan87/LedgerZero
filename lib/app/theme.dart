import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/dimensions.dart';

class AppColors {
  // We use a modern Teal seed color for a financial/safe yet vibrant look.
  static const Color seedColor = Color(0xFF009688); // Vibrant Teal

  // Semantic Colors
  static const Color income = Color(0xFF2E7D32); // Green 800
  static const Color expense = Color(0xFFC62828); // Red 800
  static const Color success = Color(0xFF2E7D32); // Same as income/success
  static const Color warning = Color(0xFFF57C00); // Orange 700
  static const Color info = Color(0xFF0288D1); // Light Blue 700
  static const Color error = Color(0xFFBA1A1A); // M3 Error

  // Legacy/Static Light Colors (Mapped to M3 Teal Seed approx)
  static const Color primaryLight = Color(0xFF006A60);
  static const Color onPrimaryLight = Colors.white;
  static const Color primaryContainerLight = Color(0xFF74F8E5);
  static const Color onPrimaryContainerLight = Color(0xFF00201C);

  static const Color secondaryLight = Color(0xFF4A635F);
  static const Color onSecondaryLight = Colors.white;
  static const Color secondaryContainerLight = Color(0xFFCCE8E2);
  static const Color onSecondaryContainerLight = Color(0xFF05201C);

  static const Color tertiaryLight = Color(0xFF456179);
  static const Color onTertiaryLight = Colors.white;

  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color onErrorLight = Colors.white;

  static const Color backgroundLight = Color(0xFFFBFDFA);
  static const Color surfaceLight = Color(0xFFFBFDFA);
  static const Color onSurfaceLight = Color(0xFF191C1B);

  // Legacy/Static Dark Colors
  static const Color primaryDark = Color(0xFF53DBC9);
  static const Color onPrimaryDark = Color(0xFF003732);
  static const Color primaryContainerDark = Color(0xFF005048);
  static const Color onPrimaryContainerDark = Color(0xFF74F8E5);

  static const Color secondaryDark = Color(0xFFB1CCC6);
  static const Color onSecondaryDark = Color(0xFF1C3531);
  static const Color secondaryContainerDark = Color(0xFF334B47);
  static const Color onSecondaryContainerDark = Color(0xFFCCE8E2);

  static const Color tertiaryDark = Color(0xFFACC9E5);
  static const Color onTertiaryDark = Color(0xFF133248);

  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color onErrorDark = Color(0xFF690005);

  static const Color backgroundDark = Color(0xFF191C1B);
  static const Color surfaceDark = Color(0xFF191C1B);
  static const Color onSurfaceDark = Color(0xFFE1E3DF);
}

class AppTextStyles {
  // Material 3 Typography Scale Mapping
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600, // Slightly bolder for headlines
    letterSpacing: 0,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.29,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500, // Medium weight for titles
    letterSpacing: 0,
    height: 1.27,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
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

      // Global Font Family (if we had Google Fonts, we'd apply it here)
      // fontFamily: 'Inter',
      textTheme:
          const TextTheme(
            displayLarge: AppTextStyles.displayLarge,
            displayMedium: AppTextStyles.displayMedium,
            headlineLarge: AppTextStyles.headlineLarge,
            headlineMedium: AppTextStyles.headlineMedium,
            titleLarge: AppTextStyles.titleLarge,
            bodyLarge: AppTextStyles.bodyLarge,
            bodyMedium: AppTextStyles.bodyMedium,
            labelSmall: AppTextStyles.labelSmall,
          ).apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),

      scaffoldBackgroundColor: colorScheme.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle:
            false, // M3 default is often left-aligned, but we can keep centered if preferred. M3 is usually left.
        elevation: 0,
        scrolledUnderElevation: 2,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      cardTheme: CardThemeData(
        color: colorScheme
            .surfaceContainerLow, // Slightly varied surface for cards
        elevation: 0, // M3 uses filled cards mostly, or outlined
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg), // 16.0
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppRadius.full,
            ), // Capsule shape is standard M3
          ),
          textStyle: AppTextStyles.labelSmall.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
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
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppRadius.lg,
          ), // M3 square-ish FAB
        ),
      ),

      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
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
