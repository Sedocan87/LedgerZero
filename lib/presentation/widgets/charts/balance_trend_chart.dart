import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';

/// Running balance of an account over its transactions.
///
/// Screen readers get a summary: date range and lowest, highest and latest
/// balance.
class BalanceTrendChart extends ConsumerWidget {
  final List<Transaction> transactions;

  /// The account's starting balance in minor units.
  final int startingBalance;

  /// Currency of the account; defaults to the Settings currency.
  final String? currencyCode;

  const BalanceTrendChart({
    super.key,
    required this.transactions,
    required this.startingBalance,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // Split children are already contained in their parent's amount.
    final sorted =
        transactions.where((t) => t.parentTransactionId == null).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            l10n.noTransactionsTrend,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final points = <DataPoint>[];
    var runningBalance = startingBalance;

    // Initial point
    points.add(
      DataPoint(
        sorted.first.date.subtract(const Duration(days: 1)),
        startingBalance,
      ),
    );

    for (var t in sorted) {
      runningBalance += t.amount;
      points.add(DataPoint(t.date, runningBalance));
    }

    final summary = l10n.chartLineSemantics(
      lineSeriesSemanticsLabel(
        l10n: l10n,
        formatter: ref.watch(appFormatterProvider),
        name: l10n.balanceTrend,
        points: [for (final p in points) TimeSeriesPoint(p.date, p.value)],
        currencyCode: currencyCode,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.balanceTrend,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: summary,
            excludeSemantics: true,
            child: SizedBox(
              height: 150,
              width: double.infinity,
              // Own layer, like the other charts: the account screen's list
              // repaints do not repaint the chart.
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ChartPainter(
                    points: points,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DataPoint {
  final DateTime date;

  /// Balance in minor units.
  final int value;
  DataPoint(this.date, this.value);
}

class ChartPainter extends CustomPainter {
  final List<DataPoint> points;
  final Color color;

  ChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final minX = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.date.millisecondsSinceEpoch.toDouble();
    // Coordinates only: minor units as doubles.
    final minY = points.map((e) => e.value).reduce(min).toDouble();
    final maxY = points.map((e) => e.value).reduce(max).toDouble();

    final xRange = maxX - minX;
    final yRange = maxY - minY;

    final safeXRange = xRange == 0 ? 1 : xRange;
    final safeYRange = yRange == 0 ? 1 : yRange;

    final path = Path();

    double getX(double t) => (t - minX) / safeXRange * size.width;
    double getY(double v) =>
        size.height - ((v - minY) / safeYRange * size.height);

    path.moveTo(
      getX(points.first.date.millisecondsSinceEpoch.toDouble()),
      getY(points.first.value.toDouble()),
    );

    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        getX(points[i].date.millisecondsSinceEpoch.toDouble()),
        getY(points[i].value.toDouble()),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
