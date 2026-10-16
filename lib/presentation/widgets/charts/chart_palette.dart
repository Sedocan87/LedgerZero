import 'package:flutter/material.dart';

/// What a line series shows; the palette maps it to a colour.
enum ChartSeriesKind { income, expense, netWorth }

/// Chart colours derived from the active [ColorScheme].
///
/// Registered as a [ThemeExtension] on every app theme (see
/// `AppTheme`), so charts follow light, dark and high-contrast mode. The
/// categorical colours (pie slices) are the primary colours of schemes
/// seeded with hues spread around the colour wheel from the theme's own
/// hue, at the tone Material uses for `primary` in the theme's brightness,
/// so every slice keeps at least 3:1 contrast with the surface (4.5:1 in
/// high contrast). Consecutive colours are far apart in hue.
@immutable
class ChartPalette extends ThemeExtension<ChartPalette> {
  const ChartPalette({
    required this.categorical,
    required this.income,
    required this.expense,
    required this.netWorth,
    required this.bar,
    required this.secondaryBar,
    required this.budgeted,
    required this.spent,
  });

  /// Number of distinct categorical colours.
  static const int categoricalCount = 8;

  /// Hue offsets (in eighths of the circle) in the order the colours are
  /// handed out: neighbours differ by at least 90 degrees.
  static const List<int> _hueOrder = [0, 4, 2, 6, 1, 5, 3, 7];

  /// Builds the palette for [scheme]. [highContrast] raises the contrast of
  /// the categorical colours (Material contrast level 1.0).
  factory ChartPalette.fromScheme(
    ColorScheme scheme, {
    bool highContrast = false,
  }) {
    // primaryContainer keeps the seed hue even in the high-contrast themes,
    // whose primary is plain black or white.
    final base = HSLColor.fromColor(scheme.primaryContainer);
    final categorical = [
      for (final step in _hueOrder)
        ColorScheme.fromSeed(
          seedColor: HSLColor.fromAHSL(
            1,
            (base.hue + step * 360 / categoricalCount) % 360,
            0.7,
            0.5,
          ).toColor(),
          brightness: scheme.brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
          contrastLevel: highContrast ? 1.0 : 0.0,
        ).primary,
    ];
    return ChartPalette(
      categorical: List.unmodifiable(categorical),
      income: scheme.primary,
      expense: scheme.error,
      netWorth: highContrast ? scheme.primary : scheme.tertiary,
      bar: scheme.primary,
      secondaryBar: highContrast ? scheme.primary : scheme.secondary,
      budgeted: scheme.primary,
      spent: scheme.error,
    );
  }

  /// The palette of the current theme; derived from its colour scheme when
  /// the theme does not carry one (e.g. a plain `ThemeData()` in tests).
  static ChartPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ChartPalette>() ??
        ChartPalette.fromScheme(theme.colorScheme);
  }

  /// Colours for categories (pie slices), in hand-out order.
  final List<Color> categorical;

  final Color income;
  final Color expense;
  final Color netWorth;

  /// Main bar colour (e.g. spending by category).
  final Color bar;

  /// Bar colour for a second bar chart on the same screen (spending trend).
  final Color secondaryBar;

  /// Budget vs. actual bars.
  final Color budgeted;
  final Color spent;

  /// The categorical colour for the [index]-th category.
  Color categoryColor(int index) => categorical[index % categorical.length];

  Color seriesColor(ChartSeriesKind kind) => switch (kind) {
    ChartSeriesKind.income => income,
    ChartSeriesKind.expense => expense,
    ChartSeriesKind.netWorth => netWorth,
  };

  @override
  ChartPalette copyWith({
    List<Color>? categorical,
    Color? income,
    Color? expense,
    Color? netWorth,
    Color? bar,
    Color? secondaryBar,
    Color? budgeted,
    Color? spent,
  }) => ChartPalette(
    categorical: categorical ?? this.categorical,
    income: income ?? this.income,
    expense: expense ?? this.expense,
    netWorth: netWorth ?? this.netWorth,
    bar: bar ?? this.bar,
    secondaryBar: secondaryBar ?? this.secondaryBar,
    budgeted: budgeted ?? this.budgeted,
    spent: spent ?? this.spent,
  );

  @override
  ChartPalette lerp(ChartPalette? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return ChartPalette(
      categorical: [
        for (var i = 0; i < categorical.length; i++)
          mix(categorical[i], other.categoryColor(i)),
      ],
      income: mix(income, other.income),
      expense: mix(expense, other.expense),
      netWorth: mix(netWorth, other.netWorth),
      bar: mix(bar, other.bar),
      secondaryBar: mix(secondaryBar, other.secondaryBar),
      budgeted: mix(budgeted, other.budgeted),
      spent: mix(spent, other.spent),
    );
  }
}
