/// Represents the breakdown of assets and liabilities.
class AssetLiabilityBreakdown {
  /// The total value of all asset accounts (Checking, Savings, Cash).
  final double totalAssets;

  /// The total value of all liability accounts (Credit).
  final double totalLiabilities;

  /// The calculated net worth (Assets + Liabilities).
  /// Note: Liabilities are typically stored as negative numbers, so simple addition works.
  /// However, for display purposes, we might want to know the magnitude.
  /// Here, we assume [totalAssets] is positive and [totalLiabilities] is signed (negative).
  final double netWorth;

  const AssetLiabilityBreakdown({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
  });

  @override
  String toString() {
    return 'AssetLiabilityBreakdown(assets: $totalAssets, liabilities: $totalLiabilities, net: $netWorth)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AssetLiabilityBreakdown &&
        other.totalAssets == totalAssets &&
        other.totalLiabilities == totalLiabilities &&
        other.netWorth == netWorth;
  }

  @override
  int get hashCode => Object.hash(totalAssets, totalLiabilities, netWorth);
}

/// Represents spending statistics for a given period.
class SpendingStats {
  /// The average spending per day.
  final double averageDailySpending;

  /// The average spending per week.
  final double averageWeeklySpending;

  /// The average spending per month.
  final double averageMonthlySpending;

  /// Total spending in the period.
  final double totalSpending;

  const SpendingStats({
    required this.averageDailySpending,
    required this.averageWeeklySpending,
    required this.averageMonthlySpending,
    required this.totalSpending,
  });

  @override
  String toString() {
    return 'SpendingStats(daily: $averageDailySpending, weekly: $averageWeeklySpending, monthly: $averageMonthlySpending, total: $totalSpending)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SpendingStats &&
        other.averageDailySpending == averageDailySpending &&
        other.averageWeeklySpending == averageWeeklySpending &&
        other.averageMonthlySpending == averageMonthlySpending &&
        other.totalSpending == totalSpending;
  }

  @override
  int get hashCode => Object.hash(
    averageDailySpending,
    averageWeeklySpending,
    averageMonthlySpending,
    totalSpending,
  );
}

/// Represents a single year's financial summary.
class YearlySummary {
  final int year;
  final double income;
  final double expense;
  final double netSavings;

  const YearlySummary({
    required this.year,
    required this.income,
    required this.expense,
    required this.netSavings,
  });

  @override
  String toString() {
    return 'YearlySummary(year: $year, income: $income, expense: $expense, savings: $netSavings)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is YearlySummary &&
        other.year == year &&
        other.income == income &&
        other.expense == expense &&
        other.netSavings == netSavings;
  }

  @override
  int get hashCode => Object.hash(year, income, expense, netSavings);
}

/// Represents a comparison between two years.
class YearlyComparisonData {
  /// The primary year being analyzed.
  final YearlySummary currentYear;

  /// The previous year for comparison.
  final YearlySummary previousYear;

  const YearlyComparisonData({
    required this.currentYear,
    required this.previousYear,
  });

  /// The percentage change in income (e.g., 0.10 for +10%).
  double get incomeChangePercentage {
    if (previousYear.income == 0) return 0.0;
    return (currentYear.income - previousYear.income) / previousYear.income;
  }

  /// The percentage change in expense.
  double get expenseChangePercentage {
    if (previousYear.expense == 0) return 0.0;
    return (currentYear.expense - previousYear.expense) / previousYear.expense;
  }

  /// The percentage change in net savings.
  double get savingsChangePercentage {
    if (previousYear.netSavings == 0) return 0.0;
    return (currentYear.netSavings - previousYear.netSavings) / previousYear.netSavings;
  }

  @override
  String toString() {
    return 'YearlyComparisonData(current: $currentYear, previous: $previousYear)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is YearlyComparisonData &&
        other.currentYear == currentYear &&
        other.previousYear == previousYear;
  }

  @override
  int get hashCode => Object.hash(currentYear, previousYear);
}
