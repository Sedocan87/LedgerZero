import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/charts/chart_data_models.dart';

/// Running balance of an account, one point per day (the balance at the
/// end of that day).
///
/// Screen readers get a summary: date range and lowest, highest and latest
/// balance.
class BalanceTrendChart extends ConsumerWidget {
  /// Per calendar day, the sum of the account's rows, oldest day first
  /// (e.g. `TransactionsDao.watchDailyTotals`, aggregated in SQL).
  final List<({DateTime date, int total})> dailyTotals;

  /// The account's starting balance in minor units.
  final int startingBalance;

  /// Currency of the account; defaults to the Settings currency.
  final String? currencyCode;

  const BalanceTrendChart.daily({
    super.key,
    required this.dailyTotals,
    required this.startingBalance,
    this.currencyCode,
  });

  /// From the account's [transactions] (split lines are skipped: their
  /// parent carries the amount).
  BalanceTrendChart({
    super.key,
    required List<Transaction> transactions,
    required this.startingBalance,
    this.currencyCode,
  }) : dailyTotals = _dailyTotalsOf(transactions);

  static List<({DateTime date, int total})> _dailyTotalsOf(
    List<Transaction> transactions,
  ) {
    final byDay = <DateTime, int>{};
    for (final t in transactions) {
      if (t.parentTransactionId == null) {
        byDay[t.date] = (byDay[t.date] ?? 0) + t.amount;
      }
    }
    final days = byDay.keys.toList()..sort();
    return [for (final d in days) (date: d, total: byDay[d]!)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    if (dailyTotals.isEmpty) {
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
        dailyTotals.first.date.subtract(const Duration(days: 1)),
        startingBalance,
      ),
    );

    for (final day in dailyTotals) {
      runningBalance += day.total;
      points.add(DataPoint(day.date, runningBalance));
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
