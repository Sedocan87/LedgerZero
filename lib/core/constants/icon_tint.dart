import 'package:flutter/material.dart';

/// The shade of a colour family an icon is drawn in, so that it stands out
/// on a faint badge of its own colour on the app's surfaces: shade 300 on
/// dark themes; on light themes the lightest of shades 700, 800 and 900
/// that keeps 3.3:1 on the badge (amber and orange are darkened further).
/// Used by category icons and the Settings rows.
abstract final class IconTint {
  /// The light shade of each family, worked out once.
  static final Map<MaterialColor, Color> _lightShades = {};

  /// A light surface a little darker than the app's (white rows, light grey
  /// cards), so the result has a margin on every real one.
  static const Color _lightReference = Color(0xFFE8E8E8);

  /// How strongly the badge behind the icon is tinted.
  static const double badgeAlpha = 0.14;

  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// The shade of [swatch] for an icon on a theme of [brightness].
  static Color of(MaterialColor swatch, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return swatch.shade300;
    }
    return _lightShades.putIfAbsent(swatch, () {
      bool readable(Color c) =>
          contrast(
            c,
            Color.alphaBlend(c.withValues(alpha: badgeAlpha), _lightReference),
          ) >=
          3.3;
      for (final shade in [swatch.shade700, swatch.shade800, swatch.shade900]) {
        if (readable(shade)) {
          return shade;
        }
      }
      var hsl = HSLColor.fromColor(swatch.shade900);
      while (!readable(hsl.toColor()) && hsl.lightness > 0.1) {
        hsl = hsl.withLightness(hsl.lightness - 0.03);
      }
      return hsl.toColor();
    });
  }
}
