// The rule editor's "Add action" dialog on a real database.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/rules/add_edit_rule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';
import '../../../widget_test_helpers.dart';

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
  });
  tearDown(() => t.close());

  Future<void> pumpScreen(WidgetTester tester, {String? ruleId}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestWidget(
      tester,
      overrides: [
        databaseProvider.overrideWithValue(t.db),
        // The amount of a condition is shown with the app's formatter.
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: AddEditRuleScreen(ruleId: ruleId),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
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

  group('operators per field (ledger F5)', () {
    Finder operatorItems(String label) =>
        find.widgetWithText(DropdownMenuItem<RuleConditionOperator>, label);

    testWidgets('switching the field to Amount offers only numeric '
        'comparisons and resets the operator', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Add condition'));
      await tester.pumpAndSettle();
      // Memo / description starts with "contains".
      expect(find.text('contains'), findsOneWidget);

      await tester.tap(find.text('Memo / description'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amount').last);
      await tester.pumpAndSettle();
      expect(find.text('contains'), findsNothing);
      expect(find.text('is'), findsOneWidget);

      await tester.tap(find.text('is'));
      await tester.pumpAndSettle();
      for (final label in ['is', 'is greater than', 'is less than']) {
        expect(operatorItems(label), findsWidgets);
      }
      for (final label in [
        'contains',
        'starts with',
        'ends with',
        'matches pattern (regex)',
      ]) {
        expect(operatorItems(label), findsNothing);
      }
      await tester.tap(find.text('is less than').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '-50',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('is less than'), findsOneWidget);
      expect(find.byKey(const Key('rule.condition.unevaluable')), findsNothing);

      await unmount(tester);
    });

    testWidgets('a stored condition that can never match is marked and '
        'blocks Save until it is deleted', (tester) async {
      const stored = Rule(
        id: 'dead',
        name: 'Big spend',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.amount,
            operator: RuleConditionOperator.contains,
            value: '-5000',
          ),
          RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.contains,
            value: 'shop',
          ),
        ],
        actions: [RuleAction(type: RuleActionType.setMemo, value: 'x')],
      );
      await tester.runAsync(() => t.rules.createRule(stored));
      await pumpScreen(tester, ruleId: 'dead');
      expect(
        find.byKey(const Key('rule.condition.unevaluable')),
        findsOneWidget,
      );

      final save = find.text('Save rule');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('Delete the conditions marked "Never matches" first.'),
        findsOneWidget,
      );
      final unchanged = await tester.runAsync(() => t.rules.getRule('dead'));
      expect(unchanged!.conditions, hasLength(2));

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rule.condition.unevaluable')), findsNothing);

      await unmount(tester);
    });
  });
}
