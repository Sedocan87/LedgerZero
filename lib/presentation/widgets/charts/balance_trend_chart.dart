import 'package:flutter/material.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'dart:math';
import 'package:ledger_zero/l10n/app_localizations.dart';

class BalanceTrendChart extends StatelessWidget {
  final List<Transaction> transactions;
  final double startingBalance;

  const BalanceTrendChart({
    super.key,
    required this.transactions,
    required this.startingBalance,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (transactions.isEmpty) {
      return SizedBox(
          height: 150,
          child: Center(
              child: Text(l10n.noTransactionsTrend,
                  style: Theme.of(context).textTheme.bodySmall)));
    }

    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final points = <DataPoint>[];
    double runningBalance = startingBalance;

    // Initial point
    points.add(DataPoint(sorted.first.date.subtract(const Duration(days: 1)), startingBalance));

    for (var t in sorted) {
      runningBalance += t.amount;
      points.add(DataPoint(t.date, runningBalance));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.balanceTrend, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: CustomPaint(
              painter: ChartPainter(
                points: points,
                color: Theme.of(context).colorScheme.primary,
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
  final double value;
  DataPoint(this.date, this.value);
}

class ChartPainter extends CustomPainter {
  final List<DataPoint> points;
  final Color color;

  ChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final minX = points.first.date.millisecondsSinceEpoch.toDouble();
    final maxX = points.last.date.millisecondsSinceEpoch.toDouble();
    final minY = points.map((e) => e.value).reduce(min);
    final maxY = points.map((e) => e.value).reduce(max);

    final xRange = maxX - minX;
    final yRange = maxY - minY;

    final safeXRange = xRange == 0 ? 1 : xRange;
    final safeYRange = yRange == 0 ? 1 : yRange;

    final path = Path();

    double getX(double t) => (t - minX) / safeXRange * size.width;
    double getY(double v) => size.height - ((v - minY) / safeYRange * size.height);

    path.moveTo(getX(points.first.date.millisecondsSinceEpoch.toDouble()), getY(points.first.value));

    for (int i = 1; i < points.length; i++) {
      path.lineTo(getX(points[i].date.millisecondsSinceEpoch.toDouble()), getY(points[i].value));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
