import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final Map<String, double> data;
  final double height;
  final Color barColor;
  final Color labelColor;
  final bool preserveOrder;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.height = 200,
    required this.barColor,
    required this.labelColor,
    this.preserveOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(color: labelColor),
          ),
        ),
      );
    }

    List<MapEntry<String, double>> entries;
    if (preserveOrder) {
      entries = data.entries.toList();
    } else {
      final sortedEntries = data.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // Descending

      // Show top 7 categories + Others
      entries = sortedEntries.take(7).toList();
      if (sortedEntries.length > 7) {
        final otherSum = sortedEntries.skip(7).fold(0.0, (sum, item) => sum + item.value);
        entries.add(MapEntry('Others', otherSum));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: height,
          width: constraints.maxWidth,
          child: CustomPaint(
            painter: BarChartPainter(
              data: entries,
              barColor: barColor,
              labelColor: labelColor,
            ),
          ),
        );
      },
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final Color barColor;
  final Color labelColor;

  BarChartPainter({
    required this.data,
    required this.barColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    // Reserve space for bottom labels (e.g. 40px)
    const double bottomMargin = 40.0;
    const double topMargin = 20.0;

    final chartHeight = size.height - bottomMargin - topMargin;
    final maxVal = data.map((e) => e.value).reduce(max);
    // Prevent div by zero
    final safeMaxVal = maxVal == 0 ? 1.0 : maxVal;

    final barWidth = (size.width / data.length) * 0.6;
    final spacing = (size.width / data.length) * 0.4;

    for (int i = 0; i < data.length; i++) {
      final entry = data[i];
      final barHeight = (entry.value / safeMaxVal) * chartHeight;

      final left = (i * (barWidth + spacing)) + (spacing / 2);
      final top = size.height - bottomMargin - barHeight;
      final right = left + barWidth;
      final bottom = size.height - bottomMargin;

      // Draw bar
      final rRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(4),
      );
      canvas.drawRRect(rRect, paint);

      // Draw Value on top
      final valSpan = TextSpan(
        text: compactCurrency(entry.value),
        style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold),
      );
      final valPainter = TextPainter(
        text: valSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      valPainter.layout(minWidth: barWidth);
      valPainter.paint(
        canvas,
        Offset(left, top - 15)
      );

      // Draw Label (Category Name) - with ellipsis
      final textSpan = TextSpan(
        text: entry.key,
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '...',
      );
      // Allow slightly wider than bar for text
      textPainter.layout(maxWidth: barWidth + spacing);

      // Paint centered under bar
      textPainter.paint(
        canvas,
        Offset(left - (spacing/2) + (barWidth + spacing - textPainter.width)/2, bottom + 5)
      );
    }
  }

  String compactCurrency(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
