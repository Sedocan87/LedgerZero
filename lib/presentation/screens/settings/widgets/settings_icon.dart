import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/icon_tint.dart';

/// The icon of a Settings row: drawn in its own colour on a faint badge of
/// that colour, like the category icons on the budget screen.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {required this.color, super.key});

  final IconData icon;

  /// The colour family; the shade follows the theme ([IconTint]).
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    final tint = IconTint.of(color, Theme.of(context).brightness);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: IconTint.badgeAlpha),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: tint),
    );
  }
}
