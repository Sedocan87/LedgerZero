import 'package:flutter/material.dart';

class TimeSeriesPoint {
  final DateTime date;
  final double value;

  const TimeSeriesPoint(this.date, this.value);
}

class ChartSeries {
  final String name;
  final Color color;
  final List<TimeSeriesPoint> points;

  const ChartSeries({
    required this.name,
    required this.color,
    required this.points,
  });
}

class BudgetVsActualItem {
  final String categoryName;
  final double budgeted;
  final double actual;

  BudgetVsActualItem({
    required this.categoryName,
    required this.budgeted,
    required this.actual,
  });
}
