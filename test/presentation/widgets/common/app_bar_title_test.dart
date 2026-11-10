import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/common/app_bar_title.dart';

void main() {
  testWidgets('a long title scales down to its space instead of being cut', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 120, child: AppBarTitle('Transaktionen')),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Transaktionen'),
    );
    // Laid out at its full width, never ellipsised ...
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.width, greaterThan(120));
    // ... and drawn within the 120 dp it has.
    expect(
      tester.getRect(find.text('Transaktionen')).width,
      lessThanOrEqualTo(120),
    );
  });

  testWidgets('a short title keeps its size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 400, child: AppBarTitle('Home')),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Home'));
    // Drawn at its natural size: no scaling when it fits.
    expect(
      tester.getRect(find.text('Home')).width,
      closeTo(paragraph.size.width, 0.01),
    );
  });
}
