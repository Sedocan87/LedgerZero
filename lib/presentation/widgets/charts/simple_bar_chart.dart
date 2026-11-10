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

      // Category name under the bar, never broken inside a word.
      final textPainter = fitBarLabel(
        entry.key,
        maxWidth: barWidth + spacing,
        color: labelColor,
      );

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

/// The label under a bar: at most two lines in [maxWidth], broken only
/// between words. The font shrinks from 10 to 8 px until the longest word
/// fits; a word that does not fit even then gets one line with an ellipsis
/// ("Transporta…"), never a word split over two lines ("Groceri" / "es").
@visibleForTesting
TextPainter fitBarLabel(
  String text, {
  required double maxWidth,
  required Color color,
}) {
  TextPainter painter(double size, int maxLines) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: size),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    ellipsis: '…',
  );
  double widestWord(double size) {
    var widest = 0.0;
    // A line may also break after "/" ("Rent/" "Mortgage").
    for (final word in text.split(RegExp(r'(?<=/)|\s+'))) {
      final p = TextPainter(
        text: TextSpan(
          text: word,
          style: TextStyle(fontSize: size),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      widest = max(widest, p.width);
      p.dispose();
    }
    return widest;
  }

  for (var size = 10.0; size >= 8.0; size -= 0.5) {
    if (widestWord(size) <= maxWidth) {
      return painter(size, 2)..layout(maxWidth: maxWidth);
    }
  }
  return painter(8.0, 1)..layout(maxWidth: maxWidth);
}
