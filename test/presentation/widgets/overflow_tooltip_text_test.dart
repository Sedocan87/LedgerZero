import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/widgets/common/overflow_tooltip_text.dart';

void main() {
  Widget build(String text) => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          SizedBox(width: 80, child: OverflowTooltipText(text)),
          const SizedBox(height: 200, child: Text('elsewhere')),
        ],
      ),
    ),
  );

  testWidgets('a name that fits has no tooltip', (tester) async {
    await tester.pumpWidget(build('Rent'));
    expect(find.byType(Tooltip), findsNothing);
  });

  testWidgets('a cut-off name shows in full on tap until the next tap', (
    tester,
  ) async {
    const name = 'Emergency fund for unexpected car repairs';
    await tester.pumpWidget(build(name));
    expect(find.byType(Tooltip), findsOneWidget);
    // Only the label, not the tooltip yet.
    expect(find.text(name), findsOneWidget);

    await tester.tap(find.byType(OverflowTooltipText));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(name), findsNWidgets(2));

    await tester.tap(find.text('elsewhere'));
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);
  });

  testWidgets('it also closes by itself', (tester) async {
    const name = 'Emergency fund for unexpected car repairs';
    await tester.pumpWidget(build(name));
    await tester.tap(find.byType(OverflowTooltipText));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(name), findsNWidgets(2));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);
  });
  testWidgets('a word too long for the space is not broken in the middle', (
    tester,
  ) async {
    await tester.pumpWidget(build('Lebensmittelvorrat'));
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(OverflowTooltipText),
        matching: find.byType(Text),
      ),
    );
    expect(text.maxLines, 1);
    expect(find.byType(Tooltip), findsOneWidget);
  });

  testWidgets('words that fit wrap onto a second line', (tester) async {
    await tester.pumpWidget(build('Car fuel'));
    final text = tester.widget<Text>(find.text('Car fuel'));
    expect(text.maxLines, 2);
    expect(find.byType(Tooltip), findsNothing);
  });
  testWidgets('a long second word moves to the second line whole', (
    tester,
  ) async {
    await tester.pumpWidget(build('Car Lebensmittelvorrat'));
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(OverflowTooltipText),
        matching: find.byType(Text),
      ),
    );
    // "Car" stays whole on the first line (an explicit break when the
    // engine would split the long word across both lines).
    expect(
      text.data,
      anyOf('Car\nLebensmittelvorrat', 'Car Lebensmittelvorrat'),
    );
    expect(text.maxLines, 2);
    // Screen readers still get the name as typed.
    expect(text.semanticsLabel, 'Car Lebensmittelvorrat');
    expect(find.byType(Tooltip), findsOneWidget);
  });
}
