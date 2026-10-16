import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/money/money.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';

/// Bar chart of amounts (minor units) per label.
///
/// Screen readers get one summary label with every bar's amount.
class SimpleBarChart extends ConsumerWidget {
  /// Label -> amount in minor units.
  final Map<String, int> data;
  final double height;
  final Color barColor;
  final Color labelColor;
  final bool preserveOrder;

  /// Currency of the amounts; defaults to the Settings currency.
  final String? currencyCode;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.height = 200,
    required this.barColor,
    required this.labelColor,
    this.preserveOrder = false,
    this.currencyCode,
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

    final fmt = ref.watch(appFormatterProvider);

    List<MapEntry<String, int>> entries;
    if (preserveOrder) {
      entries = data.entries.toList();
    } else {
      final sortedEntries = data.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // Descending

      // Show top 7 categories + Others
      entries = sortedEntries.take(7).toList();
      if (sortedEntries.length > 7) {
        final otherSum = Money.sum(sortedEntries.skip(7).map((e) => e.value));
        entries.add(MapEntry(l10n.chartOthers, otherSum));
      }
    }

    final semanticDescription = entries
        .map(
          (e) =>
              '${e.key}: ${fmt.formatMoney(e.value, currencyCode: currencyCode)}',
        )
        .join(', ');

    return LayoutBuilder(
      builder: (context, constraints) {
        return Semantics(
          label: l10n.chartBarSemantics(semanticDescription),
          excludeSemantics: true,
          child: SizedBox(
            height: height,
            width: constraints.maxWidth,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: BarChartPainter(
                  data: entries,
                  barColor: barColor,
                  labelColor: labelColor,
                  formatter: fmt,
                  currencyCode: currencyCode,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BarChartPainter extends CustomPainter {
  /// Label -> amount in minor units.
  final List<MapEntry<String, int>> data;
  final Color barColor;
  final Color labelColor;

  /// Formats the value label drawn above each bar.
  final AppFormatter formatter;

  /// Currency of the amounts; defaults to the formatter's currency.
  final String? currencyCode;

  BarChartPainter({
    required this.data,
    required this.barColor,
    required this.labelColor,
    required this.formatter,
    this.currencyCode,
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
    final safeMaxVal = maxVal == 0 ? 1 : maxVal;

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
        text: formatter.formatMoneyCompact(
          entry.value,
          currencyCode: currencyCode,
        ),
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final valPainter = TextPainter(
        text: valSpan,
        textDirection: ui.TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      valPainter.layout(minWidth: barWidth);
      valPainter.paint(canvas, Offset(left, top - 15));

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
        Offset(
          left - (spacing / 2) + (barWidth + spacing - textPainter.width) / 2,
          bottom + 5,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    if (oldDelegate.barColor != barColor) {
      return true;
    }
    if (oldDelegate.labelColor != labelColor) {
      return true;
    }
    if (!identical(oldDelegate.formatter, formatter) ||
        oldDelegate.currencyCode != currencyCode) {
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
