// Chart colours come from the active theme (ChartPalette theme extension)
// and must stay distinguishable from the surface and from each other in
// light, dark and both high-contrast themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _hueDistance(Color a, Color b) {
  final d = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

void main() {
  for (final (name, theme, minContrast) in [
    ('light', AppTheme.lightTheme, 3.0),
    ('dark', AppTheme.darkTheme, 3.0),
    ('high-contrast light', AppTheme.highContrastLightTheme, 4.5),
    ('high-contrast dark', AppTheme.highContrastDarkTheme, 4.5),
  ]) {
    group('$name theme', () {
      final surface = theme.colorScheme.surface;
      final palette = theme.extension<ChartPalette>();

      test('carries a chart palette', () {
        expect(palette, isNotNull);
        expect(palette!.categorical, hasLength(ChartPalette.categoricalCount));
      });

      test('categorical colours contrast with the surface', () {
        for (final (i, c) in palette!.categorical.indexed) {
          expect(
            _contrast(c, surface),
            greaterThanOrEqualTo(minContrast),
            reason: 'category $i ($c)',
          );
        }
      });

      test('categorical colours are distinct, neighbours far apart', () {
        final colors = palette!.categorical;
        expect(colors.toSet(), hasLength(colors.length));
        for (var i = 0; i + 1 < colors.length; i++) {
          expect(
            _hueDistance(colors[i], colors[i + 1]),
            greaterThanOrEqualTo(60),
            reason: 'categories $i and ${i + 1}',
          );
        }
      });

      test('series and bar colours come from the colour scheme', () {
        final scheme = theme.colorScheme;
        expect(palette!.income, scheme.primary);
        expect(palette.expense, scheme.error);
        expect(palette.budgeted, scheme.primary);
        expect(palette.spent, scheme.error);
        for (final c in [
          palette.income,
          palette.expense,
          palette.netWorth,
          palette.bar,
          palette.secondaryBar,
        ]) {
          expect(_contrast(c, surface), greaterThanOrEqualTo(3.0));
        }
      });
    });
  }

  testWidgets('of() falls back to a palette derived from a plain theme', (
    tester,
  ) async {
    late ChartPalette palette;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: Builder(
          builder: (context) {
            palette = ChartPalette.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(palette.categorical, hasLength(ChartPalette.categoricalCount));
    expect(palette.income, ThemeData().colorScheme.primary);
  });
}
