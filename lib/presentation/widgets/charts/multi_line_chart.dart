import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';

/// Line chart of one or more money time series (values in minor units).
///
/// Screen readers get one summary label: per series its date range and the
/// lowest, highest and latest value.
class MultiLineChart extends ConsumerWidget {
  final List<ChartSeries> seriesList;
  final double height;
  final Color gridColor;
  final Color labelColor;

  /// Currency of the values; defaults to the Settings currency.
  final String? currencyCode;

  const MultiLineChart({
    super.key,
    required this.seriesList,
    this.height = 200,
    required this.gridColor,
    required this.labelColor,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (seriesList.isEmpty || seriesList.every((s) => s.points.isEmpty)) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(l10n.noTransactions, style: TextStyle(color: labelColor)),
        ),
      );
    }

    final fmt = ref.watch(appFormatterProvider);
    final palette = ChartPalette.of(context);

    final seriesDescriptions = seriesList
        .where((s) => s.points.isNotEmpty)
        .map(
          (s) => lineSeriesSemanticsLabel(
            l10n: l10n,
            formatter: fmt,
            name: s.name,
            points: s.points,
            currencyCode: currencyCode,
          ),
        )
        .join('. ');

    return Semantics(
      label: l10n.chartLineSemantics(seriesDescriptions),
      excludeSemantics: true,
      child: Column(
        children: [
          // Legend
          Wrap(
            spacing: 16,
            children: seriesList.map((s) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    color: palette.seriesColor(s.kind),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    s.name,
                    style: TextStyle(color: labelColor, fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            width: double.infinity,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: MultiLineChartPainter(
                  seriesList: seriesList,
                  palette: palette,
                  gridColor: gridColor,
                  labelColor: labelColor,
                  formatter: fmt,
                  currencyCode: currencyCode,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MultiLineChartPainter extends CustomPainter {
  final List<ChartSeries> seriesList;
  final ChartPalette palette;
  final Color gridColor;
  final Color labelColor;

  /// Formats axis labels.
  final AppFormatter formatter;

  /// Currency of the values; defaults to the formatter's currency.
  final String? currencyCode;

  MultiLineChartPainter({
    required this.seriesList,
    required this.palette,
    required this.gridColor,
    required this.labelColor,
    required this.formatter,
    this.currencyCode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Margins for axes
    const double leftMargin = 40.0;
    const double bottomMargin = 20.0;
    const double rightMargin = 10.0;
    const double topMargin = 10.0;

    final chartRect = Rect.fromLTRB(
      leftMargin,
      topMargin,
      size.width - rightMargin,
      size.height - bottomMargin,
    );

    // 1. Calculate Bounds (y in minor units; doubles only as coordinates)
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var series in seriesList) {
      if (series.points.isEmpty) {
        continue;
      }
      for (var p in series.points) {
        final x = p.date.millisecondsSinceEpoch.toDouble();
        if (x < minX) {
          minX = x;
        }
        if (x > maxX) {
          maxX = x;
        }
        final v = p.value.toDouble();
        if (v < minY) {
          minY = v;
        }
        if (v > maxY) {
          maxY = v;
        }
      }
    }

    if (minX == double.infinity) {
      return;
    }

    // Add padding to Y range
    final yRange = maxY - minY;
    if (yRange == 0) {
      // +/- 10 major units
      maxY += 1000;
      minY -= 1000;
    } else {
      maxY += yRange * 0.1;
      minY -= yRange * 0.1;
    }

    final xRange = maxX - minX;
    final safeXRange = xRange == 0 ? 1.0 : xRange;
    final safeYRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    double getX(double t) =>
        chartRect.left + ((t - minX) / safeXRange) * chartRect.width;
    double getY(double v) =>
        chartRect.bottom - ((v - minY) / safeYRange) * chartRect.height;

    // 2. Draw Grid & Labels
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final labelStyle = TextStyle(color: labelColor, fontSize: 10);

    // Y-Axis Labels & Grid Lines (5 steps)
    const ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      final value = minY + (safeYRange / ySteps) * i;
      final y = getY(value);

      // Grid line
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      // Label
      final labelSpan = TextSpan(
        text: formatter.formatMoneyCompact(
          value.round(),
          currencyCode: currencyCode,
        ),
        style: labelStyle,
      );
      final textPainter = TextPainter(
        text: labelSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.right,
      );
      textPainter.layout(maxWidth: leftMargin - 5);
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    // X-Axis Labels (3 steps: Start, Middle, End)
    const xSteps = 2; // Start, Mid, End
    for (int i = 0; i <= xSteps; i++) {
      final t = minX + (safeXRange / xSteps) * i;
      final x = getX(t);
      final date = DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true);

      // Label
      final labelSpan = TextSpan(
        text: formatter.formatMonthDay(date),
        style: labelStyle,
      );
      final textPainter = TextPainter(
        text: labelSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // Adjust position to keep within bounds
      double xPos = x - textPainter.width / 2;
      if (i == 0) {
        xPos = chartRect.left; // Align left
      }
      if (i == xSteps) {
        xPos = chartRect.right - textPainter.width; // Align right
      }

      textPainter.paint(canvas, Offset(xPos, chartRect.bottom + 5));
    }

    // 3. Draw Lines
    for (var series in seriesList) {
      if (series.points.isEmpty) {
        continue;
      }

      final paint = Paint()
        ..color = palette.seriesColor(series.kind)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(
        getX(series.points.first.date.millisecondsSinceEpoch.toDouble()),
        getY(series.points.first.value.toDouble()),
      );

      for (int i = 1; i < series.points.length; i++) {
        path.lineTo(
          getX(series.points[i].date.millisecondsSinceEpoch.toDouble()),
          getY(series.points[i].value.toDouble()),
        );
      }

      canvas.save();
      canvas.clipRect(chartRect); // Clip to avoid drawing outside
      canvas.drawPath(path, paint);

      // Draw points
      final dotPaint = Paint()
        ..color = palette.seriesColor(series.kind)
        ..style = PaintingStyle.fill;
      for (var p in series.points) {
        canvas.drawCircle(
          Offset(
            getX(p.date.millisecondsSinceEpoch.toDouble()),
            getY(p.value.toDouble()),
          ),
          3,
          dotPaint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MultiLineChartPainter oldDelegate) {
    if (oldDelegate.gridColor != gridColor || oldDelegate.palette != palette) {
      return true;
    }
    if (oldDelegate.labelColor != labelColor) {
      return true;
    }
    if (!identical(oldDelegate.formatter, formatter) ||
        oldDelegate.currencyCode != currencyCode) {
      return true;
    }
    if (oldDelegate.seriesList.length != seriesList.length) {
      return true;
    }

    for (int i = 0; i < seriesList.length; i++) {
      if (seriesList[i].name != oldDelegate.seriesList[i].name) {
        return true;
      }
      if (seriesList[i].kind != oldDelegate.seriesList[i].kind) {
        return true;
      }
      if (seriesList[i].points.length !=
          oldDelegate.seriesList[i].points.length) {
        return true;
      }

      for (int j = 0; j < seriesList[i].points.length; j++) {
        if (seriesList[i].points[j].date !=
                oldDelegate.seriesList[i].points[j].date ||
            seriesList[i].points[j].value !=
                oldDelegate.seriesList[i].points[j].value) {
          return true;
        }
      }
    }
    return false;
  }
}
