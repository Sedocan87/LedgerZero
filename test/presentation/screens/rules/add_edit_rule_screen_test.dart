// The rule editor's "Add action" dialog on a real database.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/rules/add_edit_rule_screen.dart';

import '../../../helpers/test_database.dart';
import '../../../widget_test_helpers.dart';

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestWidget(
      tester,
      overrides: [databaseProvider.overrideWithValue(t.db)],
      child: const AddEditRuleScreen(),
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> addFlagAction(WidgetTester tester, String typeLabel) async {
    final addAction = find.text('Add action');
    await tester.ensureVisible(addAction);
    await tester.pumpAndSettle();
    await tester.tap(addAction);
    await tester.pumpAndSettle();

    // Default type: set category. Switch to the yes/no action.
    await tester.tap(find.text('Set category').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(typeLabel).last);
    await tester.pumpAndSettle();

    // The value dropdown shows "Yes" without being touched; Add takes it.
    expect(find.text('Yes'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await tester.pumpAndSettle();
  }

  for (final label in ['Mark as cleared', 'Mark as approved']) {
    testWidgets('"$label" can be added with its default Yes', (tester) async {
      await pumpScreen(tester);
      await addFlagAction(tester, label);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('$label: Yes'), findsOneWidget);

      await unmount(tester);
    });
  }
}
