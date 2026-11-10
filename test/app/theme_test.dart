// The app themes are generated from the teal seed colour (Material 3,
// fidelity variant). These tests pin that design and check that text on the
// generated colours stays readable (WCAG AA, 4.5:1), including the semantic
// colours (AppSemanticColors), the Inter type scale and the tonal cards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final (name, theme, brightness) in [
    ('light', AppTheme.lightTheme, Brightness.light),
    ('dark', AppTheme.darkTheme, Brightness.dark),
  ]) {
    group('$name theme', () {
      final scheme = theme.colorScheme;

      test('is Material 3 and built from the seed colour', () {
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, brightness);
        final seeded = ColorScheme.fromSeed(
          seedColor: AppColors.seedColor,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        );
        expect(scheme.primary, seeded.primary);
        expect(scheme.secondary, seeded.secondary);
        expect(scheme.surface, seeded.surface);
        expect(theme.scaffoldBackgroundColor, scheme.surface);
      });

      test('text on the main colours meets WCAG AA', () {
        for (final (fg, bg, label) in [
          (scheme.onPrimary, scheme.primary, 'onPrimary/primary'),
          (
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
            'onPrimaryContainer/primaryContainer',
          ),
          (scheme.onSurface, scheme.surface, 'onSurface/surface'),
          (scheme.onError, scheme.error, 'onError/error'),
        ]) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: label);
        }
      });
    });
  }

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
    ('high-contrast light', AppTheme.highContrastLightTheme),
    ('high-contrast dark', AppTheme.highContrastDarkTheme),
  ]) {
    group('$name theme', () {
      final scheme = theme.colorScheme;
      final semantic = theme.extension<AppSemanticColors>()!;

      test('semantic colours keep 4.5:1 on the surfaces and their own pill', () {
        for (final (color, label) in [
          (semantic.income, 'income'),
          (semantic.expense, 'expense'),
          (semantic.success, 'success'),
          (semantic.warning, 'warning'),
          (semantic.error, 'error'),
        ]) {
          for (final (background, surface) in [
            (scheme.surface, 'surface'),
            (scheme.surfaceContainerLow, 'surfaceContainerLow'),
          ]) {
            expect(
              _contrast(color, background),
              greaterThanOrEqualTo(4.5),
              reason: '$label on $surface',
            );
            expect(
              _contrast(color, AppSemanticColors.tonal(color, background)),
              greaterThanOrEqualTo(4.5),
              reason: '$label on its pill over $surface',
            );
          }
        }
        // Zero amounts and secondary text.
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHigh),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('the error colour is the colour scheme\'s', () {
        expect(semantic.error, scheme.error);
      });

      test('all text is Inter: headlines and titles 600-700, body 400, '
          'labels 500', () {
        final t = theme.textTheme;
        for (final style in [
          t.displayLarge,
          t.displayMedium,
          t.displaySmall,
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
          t.bodyLarge,
          t.bodyMedium,
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
          theme.appBarTheme.titleTextStyle,
        ]) {
          expect(style?.fontFamily, 'Inter');
        }
        for (final style in [
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
        ]) {
          expect(style!.fontWeight!.value, inInclusiveRange(600, 700));
        }
        for (final style in [t.bodyLarge, t.bodyMedium, t.bodySmall]) {
          expect(style!.fontWeight, FontWeight.w400);
        }
        for (final style in [t.labelLarge, t.labelMedium, t.labelSmall]) {
          expect(style!.fontWeight, FontWeight.w500);
        }
      });

      test('cards are tonal: a surface fill and no outline', () {
        final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(shape.side, BorderSide.none);
        expect(theme.cardTheme.color, scheme.surfaceContainerLow);
      });
    });
  }

  test('a plain theme without the extension still gets semantic colours', () {
    final light = ThemeData(brightness: Brightness.light);
    expect(
      AppSemanticColors.fromScheme(light.colorScheme).success,
      AppTheme.lightTheme.extension<AppSemanticColors>()!.success,
    );
  });

  test('tabular adds tabular figures once and keeps the style', () {
    const style = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final tabular = style.tabular;
    expect(tabular.fontFeatures, [const FontFeature.tabularFigures()]);
    expect(tabular.fontSize, 14);
    expect(tabular.fontWeight, FontWeight.w600);
    expect(tabular.tabular.fontFeatures, hasLength(1));
  });

  test('high-contrast themes use black and white', () {
    expect(AppTheme.highContrastLightTheme.colorScheme.primary, Colors.black);
    expect(AppTheme.highContrastLightTheme.colorScheme.surface, Colors.white);
    expect(AppTheme.highContrastDarkTheme.colorScheme.primary, Colors.white);
    expect(AppTheme.highContrastDarkTheme.colorScheme.surface, Colors.black);
  });
}
