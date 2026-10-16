// The app themes are generated from the teal seed colour (Material 3,
// fidelity variant). These tests pin that design and check that text on the
// generated colours stays readable (WCAG AA, 4.5:1).
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

  test('high-contrast themes use black and white', () {
    expect(AppTheme.highContrastLightTheme.colorScheme.primary, Colors.black);
    expect(AppTheme.highContrastLightTheme.colorScheme.surface, Colors.white);
    expect(AppTheme.highContrastDarkTheme.colorScheme.primary, Colors.white);
    expect(AppTheme.highContrastDarkTheme.colorScheme.surface, Colors.black);
  });
}
