import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/l10n/app_localizations_en.dart';
import 'package:ledger_zero/services/rules/rule_learning_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late RuleLearningService service;
  late String groceries;
  final day = DateTime.utc(2026, 1, 10);

  setUp(() async {
    t = TestDatabase();
    service = RuleLearningService(
      t.transactions,
      t.payees,
      AppLocalizationsEn(),
      t.rules,
    );
    groceries = await t.categoryId('Groceries');
    await t.addAccount(id: 'acc');
    await t.payees.createPayee(const Payee(id: 'p', name: 'Market'));
    for (var i = 0; i < 3; i++) {
      await t.addTransaction(
        id: 'tx$i',
        accountId: 'acc',
        amount: -100,
        date: day,
        payeeId: 'p',
        categoryId: groceries,
      );
    }
  });

  tearDown(() => t.close());

  Rule existing(String id, String payee, String category) => Rule(
    id: id,
    name: id,
    priority: 0,
    isActive: true,
    matchLogic: RuleMatchLogic.and,
    conditions: [
      RuleCondition(
        type: RuleConditionType.payee,
        operator: RuleConditionOperator.equals,
        value: payee,
      ),
    ],
    actions: [RuleAction(type: RuleActionType.setCategory, value: category)],
  );

  test('(L5) a suggestion the user already has as a rule is skipped', () async {
    expect(await service.suggestRules(), hasLength(1));
    await t.rules.createRule(existing('have', 'market', groceries));
    expect(await service.suggestRules(), isEmpty);
  });

  test('(L5) an accepted suggestion goes after the existing rules', () async {
    await t.rules.createRule(existing('a', 'Other', groceries));
    await t.rules.createRule(existing('b', 'Another', groceries));
    final suggestion = (await service.suggestRules()).single;
    final stored = await service.acceptSuggestion(suggestion);
    expect(stored.priority, 2);
    expect((await t.rules.getRule(stored.id))!.priority, 2);
  });
}
