import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';

class MultiLineChart extends StatelessWidget {
  final List<ChartSeries> seriesList;
  final double height;
  final Color gridColor;
  final Color labelColor;

  const MultiLineChart({
    super.key,
    required this.seriesList,
    this.height = 200,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    if (seriesList.isEmpty || seriesList.every((s) => s.points.isEmpty)) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            AppLocalizations.of(context)?.noTransactions ?? 'No data available',
            style: TextStyle(color: labelColor),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Legend
        Wrap(
          spacing: 16,
          children: seriesList.map((s) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 12, height: 12, color: s.color),
                const SizedBox(width: 4),
                Text(s.name, style: TextStyle(color: labelColor, fontSize: 12)),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: MultiLineChartPainter(
              seriesList: seriesList,
              gridColor: gridColor,
              labelColor: labelColor,
            ),
          ),
        ),
      ],
    );
  }
}

class MultiLineChartPainter extends CustomPainter {
  final List<ChartSeries> seriesList;
  final Color gridColor;
  final Color labelColor;

  MultiLineChartPainter({
    required this.seriesList,
    required this.gridColor,
    required this.labelColor,
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

    // 1. Calculate Bounds
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
        if (p.value < minY) {
          minY = p.value;
        }
        if (p.value > maxY) {
          maxY = p.value;
        }
      }
    }

    if (minX == double.infinity) {
      return;
    }

    // Add padding to Y range
    final yRange = maxY - minY;
    if (yRange == 0) {
      maxY += 10;
      minY -= 10;
    } else {
      maxY += yRange * 0.1;
      minY -= yRange * 0.1;
    }

    final xRange = maxX - minX;
    final safeXRange = xRange == 0 ? 1.0 : xRange;
    final safeYRange = (maxY - minY) == 0 ? 1.0 : (maxY - minY);

    double getX(double t) => chartRect.left + ((t - minX) / safeXRange) * chartRect.width;
    double getY(double v) => chartRect.bottom - ((v - minY) / safeYRange) * chartRect.height;

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
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);

      // Label
      final labelSpan = TextSpan(text: compactCurrency(value), style: labelStyle);
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
      final date = DateTime.fromMillisecondsSinceEpoch(t.toInt());

      // Label
      final labelSpan = TextSpan(text: DateFormat.MMMd().format(date), style: labelStyle);
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
        ..color = series.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(getX(series.points.first.date.millisecondsSinceEpoch.toDouble()), getY(series.points.first.value));

      for (int i = 1; i < series.points.length; i++) {
        path.lineTo(getX(series.points[i].date.millisecondsSinceEpoch.toDouble()), getY(series.points[i].value));
      }

      canvas.save();
      canvas.clipRect(chartRect); // Clip to avoid drawing outside
      canvas.drawPath(path, paint);

      // Draw points
      final dotPaint = Paint()..color = series.color..style = PaintingStyle.fill;
      for(var p in series.points) {
         canvas.drawCircle(Offset(getX(p.date.millisecondsSinceEpoch.toDouble()), getY(p.value)), 3, dotPaint);
      }
      canvas.restore();
    }
  }

  String compactCurrency(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant MultiLineChartPainter oldDelegate) {
    if (oldDelegate.gridColor != gridColor) {
      return true;
    }
    if (oldDelegate.labelColor != labelColor) {
      return true;
    }
    if (oldDelegate.seriesList.length != seriesList.length) {
      return true;
    }

    for (int i = 0; i < seriesList.length; i++) {
      if (seriesList[i].name != oldDelegate.seriesList[i].name) {
        return true;
      }
      if (seriesList[i].color != oldDelegate.seriesList[i].color) {
        return true;
      }
      if (seriesList[i].points.length != oldDelegate.seriesList[i].points.length) {
        return true;
      }

      for(int j=0; j<seriesList[i].points.length; j++) {
         if (seriesList[i].points[j].date != oldDelegate.seriesList[i].points[j].date ||
             seriesList[i].points[j].value != oldDelegate.seriesList[i].points[j].value) {
           return true;
         }
      }
    }
    return false;
  }
}
