import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_palette.dart';

/// Pie chart of the share of each amount (minor units) in the total.
///
/// Screen readers get one summary label with every slice and its share.
class PieChart extends ConsumerWidget {
  /// Label -> amount in minor units.
  final Map<String, int> data;
  final double height;

  /// Slice colours; defaults to the theme's [ChartPalette.categorical].
  final List<Color>? colors;
  final Color labelColor;

  const PieChart({
    super.key,
    required this.data,
    this.height = 200,
    this.colors,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(l10n.noTransactions, style: TextStyle(color: labelColor)),
        ),
      );
    }
    final percentFormat = NumberFormat.decimalPercentPattern(
      locale: ref.watch(appFormatterProvider).locale,
      decimalDigits: 1,
    );
    String percentOf(int value, int total) =>
        percentFormat.format(value / total);

    final colors = this.colors ?? ChartPalette.of(context).categorical;

    // Process data: Top 7 + Others (at most 8 slices, one colour each)
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final processedData = <MapEntry<String, int>>[];

    if (sortedEntries.length > 7) {
      processedData.addAll(sortedEntries.take(7));
      final otherSum = Money.sum(sortedEntries.skip(7).map((e) => e.value));
      processedData.add(MapEntry(l10n.chartOthers, otherSum));
    } else {
      processedData.addAll(sortedEntries);
    }

    // Normalize for Pie
    final total = Money.sum(processedData.map((e) => e.value));
    if (total == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(l10n.chartTotalZero, style: TextStyle(color: labelColor)),
        ),
      );
    }

    final semanticDescription = processedData
        .map((e) => '${e.key} ${percentOf(e.value, total)}')
        .join(', ');

    return Semantics(
      label: l10n.chartPieSemantics(semanticDescription),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Chart
            Expanded(
              flex: 3,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: PieChartPainter(
                    data: processedData,
                    total: total,
                    colors: colors,
                  ),
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
                  final percentage = percentOf(entry.value, total);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entry.key}\n$percentage',
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
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  /// Label -> amount in minor units.
  final List<MapEntry<String, int>> data;

  /// Sum of [data] in minor units.
  final int total;
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

    final paint = Paint()..style = PaintingStyle.fill;

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
