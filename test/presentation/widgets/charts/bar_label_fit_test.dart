import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/charts/simple_bar_chart.dart';

import '../../../helpers/real_fonts.dart';

/// The words of [label] as the painter laid them out, one string per line.
List<String> _lines(TextPainter p, String label) => [
  for (final m in p.computeLineMetrics())
    () {
      final start = p.getPositionForOffset(
        Offset(0, m.baseline - m.ascent + 1),
      );
      final end = p.getLineBoundary(start);
      return label.substring(end.start, end.end).trim();
    }(),
];

void main() {
  setUpAll(loadInter);

  test('category names under the bars are never split inside a word', () {
    // About the slot of 8 bars on a 360 dp phone.
    const width = 40.0;
    for (final label in [
      'Groceries',
      'Transportation',
      'Rent/Mortgage',
      'Dining Out',
      'Software Subscriptions',
      'Lebensmittel',
      'Versicherungen',
    ]) {
      final p = fitBarLabel(label, maxWidth: width, color: Colors.white);
      final words = label.split(RegExp(r'(?<=/)|\s+')).toSet();
      final lines = _lines(p, label);
      if (p.didExceedMaxLines) {
        // Shortened: one line with "…", never a word over two lines.
        expect(lines, hasLength(1), reason: '"$label" -> $lines');
        continue;
      }
      for (final line in lines) {
        // Every line is whole words, or one shortened word with "…".
        final parts = line.split(RegExp(r'(?<=/)|\s+'));
        for (final part in parts) {
          expect(words, contains(part), reason: '"$label" broke into "$line"');
        }
      }
      expect(p.width, lessThanOrEqualTo(width + 0.5), reason: label);
      p.dispose();
    }
  });

  test('a name that fits keeps the full 10 px', () {
    final p = fitBarLabel('Gas', maxWidth: 60, color: Colors.white);
    expect(p.text!.style!.fontSize, 10);
    expect(p.computeLineMetrics(), hasLength(1));
  });
}
