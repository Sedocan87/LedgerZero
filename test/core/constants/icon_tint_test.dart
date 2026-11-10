import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/icon_tint.dart';

void main() {
  final families = <MaterialColor>[
    ...Colors.primaries,
    Colors.blueGrey,
    Colors.grey,
  ];

  for (final (label, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    test('$label theme: every colour family stands out on its badge (3:1)', () {
      final scheme = theme.colorScheme;
      for (final family in families) {
        final tint = IconTint.of(family, theme.brightness);
        for (final background in [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
        ]) {
          final badge = Color.alphaBlend(
            tint.withValues(alpha: IconTint.badgeAlpha),
            background,
          );
          expect(
            IconTint.contrast(tint, badge),
            greaterThanOrEqualTo(3.0),
            reason: '$family on $background',
          );
        }
      }
    });
  }

  test('light shades come from the family; amber is darkened further', () {
    // Indigo is dark enough as one of its own shades.
    expect([
      Colors.indigo.shade700,
      Colors.indigo.shade800,
      Colors.indigo.shade900,
    ], contains(IconTint.of(Colors.indigo, Brightness.light)));
    // Amber's darkest shade is still too pale on white.
    final amber = IconTint.of(Colors.amber, Brightness.light);
    expect(
      HSLColor.fromColor(amber).lightness,
      lessThan(HSLColor.fromColor(Colors.amber.shade900).lightness),
    );
  });
}
