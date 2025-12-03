import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

class PieChart extends StatelessWidget {
  final Map<String, double> data;
  final double height;
  final List<Color> colors;
  final Color labelColor;

  const PieChart({
    super.key,
    required this.data,
    this.height = 200,
    this.colors = const [
      Color(0xFF00796B), // Teal 700
      Color(0xFFFFA000), // Amber 700
      Color(0xFF455A64), // Blue Grey 700
      Color(0xFFD32F2F), // Red 700
      Color(0xFF1976D2), // Blue 700
      Color(0xFF388E3C), // Green 700
      Color(0xFF7B1FA2), // Purple 700
      Color(0xFFF57C00), // Orange 700
    ],
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
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

    // Process data: Top 7 + Others
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final processedData = <MapEntry<String, double>>[];

    if (sortedEntries.length > 7) {
        processedData.addAll(sortedEntries.take(7));
        final otherSum = sortedEntries.skip(7).fold(0.0, (sum, e) => sum + e.value);
        processedData.add(MapEntry('Others', otherSum));
    } else {
        processedData.addAll(sortedEntries);
    }

    // Normalize for Pie
    final total = processedData.fold(0.0, (sum, e) => sum + e.value);
    if (total == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Total spending is zero',
            style: TextStyle(color: labelColor),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Chart
          Expanded(
            flex: 3,
            child: CustomPaint(
              size: Size.infinite,
              painter: PieChartPainter(
                data: processedData,
                total: total,
                colors: colors,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Legend
          Expanded(
            flex: 2,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: processedData.length,
              itemBuilder: (context, index) {
                 final entry = processedData[index];
                 final percentage = (entry.value / total * 100).toStringAsFixed(1);
                 return Padding(
                   padding: const EdgeInsets.symmetric(vertical: 2.0),
                   child: Row(
                     children: [
                       Container(
                         width: 12, height: 12,
                         decoration: BoxDecoration(
                           color: colors[index % colors.length],
                           shape: BoxShape.circle,
                         ),
                       ),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           '${entry.key}\n$percentage%',
                           style: TextStyle(color: labelColor, fontSize: 11),
                           overflow: TextOverflow.ellipsis,
                           maxLines: 2,
                         ),
                       ),
                     ],
                   ),
                 );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double total;
  final List<Color> colors;

  PieChartPainter({
    required this.data,
    required this.total,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    final paint = Paint()
      ..style = PaintingStyle.fill;

    double startAngle = -pi / 2;

    for (int i = 0; i < data.length; i++) {
      final entry = data[i];
      final sweepAngle = (entry.value / total) * 2 * pi;

      paint.color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    if (oldDelegate.total != total) {
      return true;
    }
    if (oldDelegate.data.length != data.length) {
      return true;
    }

    for (int i = 0; i < data.length; i++) {
       if (data[i].key != oldDelegate.data[i].key ||
           data[i].value != oldDelegate.data[i].value) {
         return true;
       }
    }
    return false;
  }
}
