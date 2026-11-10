import 'package:flutter/material.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';

/// The columns of the budget table, shared by the column header, the group
/// headers, the category rows and the totals footer so their amounts line
/// up: `[icon] [name ...] [budgeted] ([activity]) [available pill]`.
///
/// The amount columns are as wide as a five-digit amount in the user's
/// currency format ("12.345,67 €") at the current text size, measured with
/// the styles below; wider amounts are scaled down to fit their column.
/// The name gets the rest. When that is less than [minNameWidth] (a narrow
/// phone at a large text size) the row puts the name on its own line
/// ([nameOnOwnLine]). The Activity column is only shown from
/// [activityFromWidth] of content width (tablets, landscape).
@immutable
class BudgetColumns {
  const BudgetColumns._({
    required this.budgeted,
    required this.available,
    required this.activity,
    required this.nameOnOwnLine,
  });

  /// Width of the category icon badge.
  static const double iconSize = 28;

  /// Space between the badge and the name.
  static const double iconGap = 10;

  /// Space between two columns (and between the name and the amounts).
  static const double gap = 6;

  /// Horizontal padding of the budgeted amount inside its (tappable) cell.
  static const double cellPadding = 4;

  /// Horizontal padding of the available amount inside its pill.
  static const double pillPadding = 8;

  /// The narrowest name worth showing beside the amounts.
  static const double minNameWidth = 72;

  /// Content width from which the Activity column is shown.
  static const double activityFromWidth = 560;

  /// Width of the budgeted column (padding included).
  final double budgeted;

  /// Width of the available column (the pill, padding included).
  final double available;

  /// Width of the activity column, or `null` when it is not shown.
  final double? activity;

  /// Whether the name sits on its own line above the amounts.
  final bool nameOnOwnLine;

  /// Total width of the amount columns with the gaps between them.
  double get amountsWidth =>
      budgeted + gap + available + (activity == null ? 0 : activity! + gap);

  /// Style of the budgeted (and activity) amounts.
  static TextStyle amountStyle(ThemeData theme) =>
      theme.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w500).tabular;

  /// Style of the amount in the available pill.
  static TextStyle pillStyle(ThemeData theme) => theme.textTheme.labelMedium!
      .copyWith(fontWeight: FontWeight.w600)
      .tabular;

  /// Width of the available column (it does not depend on the row width).
  static double availableWidth(BuildContext context, AppFormatter fmt) {
    final pill = _measure(
      fmt.formatMoney(-1234567),
      pillStyle(Theme.of(context)),
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );
    return (pill + 2 * pillPadding).ceilToDouble();
  }

  /// The columns for a table whose rows have [contentWidth] dp inside their
  /// horizontal padding.
  factory BudgetColumns.of(
    BuildContext context,
    AppFormatter fmt,
    double contentWidth,
  ) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final amount = _measure(
      fmt.formatMoney(1234567),
      amountStyle(theme),
      scaler,
      direction,
    );
    final pill = _measure(
      fmt.formatMoney(-1234567),
      pillStyle(theme),
      scaler,
      direction,
    );
    final budgeted = (amount + 2 * cellPadding).ceilToDouble();
    final available = (pill + 2 * pillPadding).ceilToDouble();
    final activity = contentWidth >= activityFromWidth ? budgeted : null;
    final columns = BudgetColumns._(
      budgeted: budgeted,
      available: available,
      activity: activity,
      nameOnOwnLine: false,
    );
    final nameWidth =
        contentWidth - iconSize - iconGap - gap - columns.amountsWidth;
    if (nameWidth >= minNameWidth) {
      return columns;
    }
    return BudgetColumns._(
      budgeted: budgeted,
      available: available,
      activity: activity,
      nameOnOwnLine: true,
    );
  }

  static final Map<(String, TextStyle, TextScaler, TextDirection), double>
  _widths = {};

  static double _measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final key = (text, style, scaler, direction);
    final cached = _widths[key];
    if (cached != null) {
      return cached;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (_widths.length > 32) {
      _widths.clear();
    }
    return _widths[key] = width;
  }
}
