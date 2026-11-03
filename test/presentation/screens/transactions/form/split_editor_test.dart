import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/split_editor.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';

import '../../../../widget_test_helpers.dart';

void main() {
  final formatter = AppFormatter(
    locale: 'en',
    currency: 'USD',
    decimalSeparator: '.',
  );

  /// Pumps a [SplitEditor] with one line per entry of [lines] for a
  /// transaction of [total] (unsigned minor units, `null` = no valid amount
  /// yet).
  Future<void> pumpEditor(
    WidgetTester tester, {
    required int? total,
    List<String> lines = const ['', ''],
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final items = [for (final text in lines) SplitItem(amountText: text)];
    addTearDown(() {
      for (final item in items) {
        item.dispose();
      }
    });
    await pumpTestWidget(
      tester,
      overrides: [appFormatterProvider.overrideWithValue(formatter)],
      child: StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
          child: SplitEditor(
            items: items,
            categories: const {},
            total: total,
            onChanged: () => setState(() {}),
          ),
        ),
      ),
    );
  }

  String remainder(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(splitRemainderKey)).data!;

  Color? remainderColor(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(splitRemainderKey)).style?.color;

  Finder amountField(int index) =>
      find.widgetWithText(AppTextField, 'Amount').at(index);

  testWidgets('shows the remaining amount live while lines are typed', (
    tester,
  ) async {
    await pumpEditor(tester, total: 10000);
    expect(remainder(tester), r'Remaining: $100.00');

    await tester.enterText(amountField(0), '30');
    await tester.pump();
    expect(remainder(tester), r'Remaining: $70.00');

    await tester.enterText(amountField(1), '70');
    await tester.pump();
    expect(remainder(tester), r'Remaining: $0.00');
    expect(remainderColor(tester), AppColors.success);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('says "Over by" when the lines exceed the total', (tester) async {
    await pumpEditor(tester, total: 5000, lines: ['40', '25']);
    expect(remainder(tester), r'Over by $15.00');
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('a line typed with a minus counts against the direction', (
    tester,
  ) async {
    // 120 spent, 20 of it refunded on one line: the lines add up to 100.
    await pumpEditor(tester, total: 10000, lines: ['120', '-20']);
    expect(remainder(tester), r'Remaining: $0.00');
  });

  testWidgets('no remainder without a valid total', (tester) async {
    await pumpEditor(tester, total: null, lines: ['10']);
    expect(find.byKey(splitRemainderKey), findsNothing);
  });
}
