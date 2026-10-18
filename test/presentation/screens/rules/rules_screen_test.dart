// The Rules screen's progress and suggestion dialogs on a real database.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/l10n/app_localizations_en.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/rules/rules_screen.dart';
import 'package:ledger_zero/services/rules/rule_learning_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';
import '../../../widget_test_helpers.dart';

/// Suggests whatever [suggestions] completes with (the test controls the
/// moment); accepting goes through the real rule repository.
class _ControlledLearning extends RuleLearningService {
  _ControlledLearning(TestDatabase t)
    : super(t.transactions, t.payees, AppLocalizationsEn(), t.rules);

  /// Created inside the test body: a completer made in `setUp` lives in
  /// the real zone and its completion never reaches the fake-async pumps.
  late Completer<List<Rule>> suggestions;

  @override
  Future<List<Rule>> suggestRules() => suggestions.future;
}

void main() {
  final l10n = AppLocalizationsEn();
  late TestDatabase t;
  late _ControlledLearning learning;
  late SharedPreferences prefs;

  Rule suggestion(String id) => Rule(
    id: id,
    name: 'Suggestion $id',
    description: 'desc',
    priority: 0,
    isActive: true,
    matchLogic: RuleMatchLogic.and,
    conditions: const [
      RuleCondition(
        type: RuleConditionType.payee,
        operator: RuleConditionOperator.equals,
        value: 'Market',
      ),
    ],
    actions: [RuleAction(type: RuleActionType.setMemo, value: id)],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    learning = _ControlledLearning(t);
    await t.rules.createRule(suggestion('existing').copyWith(name: 'Mine'));
  });

  tearDown(() => t.close());

  Future<void> pumpScreen(WidgetTester tester) => pumpTestWidget(
    tester,
    overrides: [
      databaseProvider.overrideWithValue(t.db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      ruleLearningServiceProvider.overrideWithValue(learning),
    ],
    child: const RulesScreen(),
  );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> startSuggest(WidgetTester tester) async {
    learning.suggestions = Completer<List<Rule>>();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.rulesMenuSuggest));
    await tester.pump();
  }

  testWidgets('(U6) the progress dialog survives Back and the barrier, and '
      'closing it never pops the Rules screen', (tester) async {
    await pumpScreen(tester);
    await startSuggest(tester);
    expect(find.byKey(const Key('rules.progress')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    expect(find.byKey(const Key('rules.progress')), findsOneWidget);
    expect(find.byType(RulesScreen), findsOneWidget);

    learning.suggestions.complete([suggestion('s1')]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rules.progress')), findsNothing);
    expect(find.byType(RulesScreen), findsOneWidget);
    expect(find.byKey(const Key('rules.suggestions')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('(L5) accepting a suggestion keeps the dialog open, removes '
      'the item and appends the rule after the existing ones', (tester) async {
    await pumpScreen(tester);
    await startSuggest(tester);
    learning.suggestions.complete([suggestion('s1'), suggestion('s2')]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rules.suggestion.accept.s1')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    // (The accepted rule now also shows in the list behind the dialog.)
    final dialog = find.byKey(const Key('rules.suggestions'));
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Suggestion s1')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Suggestion s2')),
      findsOneWidget,
    );
    expect((await t.rules.getRule('s1'))!.priority, 1);

    await tester.tap(find.byKey(const Key('rules.suggestion.accept.s2')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rules.suggestions')), findsNothing);
    expect((await t.rules.getRule('s2'))!.priority, 2);
    expect(find.byType(RulesScreen), findsOneWidget);
    await unmount(tester);
  });
}
