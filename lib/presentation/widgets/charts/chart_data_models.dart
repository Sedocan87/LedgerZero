import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';

/// One point of a money time series.
class TimeSeriesPoint {
  final DateTime date;

  /// Amount in minor units. Charts convert it to a coordinate only when
  /// painting.
  final int value;

  const TimeSeriesPoint(this.date, this.value);
}

class ChartSeries {
  final String name;

  /// What the series shows; the chart takes its colour from the theme's
  /// [ChartPalette].
  final ChartSeriesKind kind;
  final List<TimeSeriesPoint> points;

  const ChartSeries({
    required this.name,
    required this.kind,
    required this.points,
  });
}

/// Screen reader summary of one line series: its name, date range and the
/// lowest, highest and latest value. Empty when [points] is empty.
String lineSeriesSemanticsLabel({
  required AppLocalizations l10n,
  required AppFormatter formatter,
  required String name,
  required List<TimeSeriesPoint> points,
  String? currencyCode,
}) {
  if (points.isEmpty) {
    return '';
  }
  String money(int minor) =>
      formatter.formatMoney(minor, currencyCode: currencyCode);
  var minValue = points.first.value;
  var maxValue = points.first.value;
  var first = points.first;
  var last = points.first;
  for (final p in points) {
    if (p.value < minValue) {
      minValue = p.value;
    }
    if (p.value > maxValue) {
      maxValue = p.value;
    }
    if (p.date.isBefore(first.date)) {
      first = p;
    }
    if (!p.date.isBefore(last.date)) {
      last = p;
    }
  }
  return l10n.chartLineSeriesSemantics(
    name,
    formatter.formatDate(first.date),
    formatter.formatDate(last.date),
    money(minValue),
    money(maxValue),
    money(last.value),
  );
}
