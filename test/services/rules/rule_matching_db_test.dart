// Rule matching against a real database: reference checks and
// "apply to all" on the whole ledger.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late RuleMatchingService service;
  final day = DateTime.utc(2026, 2, 3);

  setUp(() async {
    t = TestDatabase();
    service = RuleMatchingService(
      t.payees,
      t.transactions,
      t.rules,
      t.categories,
      t.accounts,
      t.unitOfWork,
    );
    await t.addAccount(id: 'checking', name: 'Checking');
    await t.addAccount(id: 'old', name: 'Old');
    await t.addAccount(id: 'theirs', name: 'Theirs');
    await t.db.customStatement(
      'UPDATE accounts SET owner_id = ?, on_budget = 0 WHERE id = ?',
      ['partner-member', 'theirs'],
    );
  });

  tearDown(() => t.close());

  Rule rule(String id, List<RuleAction> actions) => Rule(
    id: id,
    name: id,
    priority: 0,
    isActive: true,
    matchLogic: RuleMatchLogic.and,
    conditions: const [
      RuleCondition(
        type: RuleConditionType.description,
        operator: RuleConditionOperator.contains,
        value: 'shop',
      ),
    ],
    actions: actions,
  );

  test('(L14) "apply to all" leaves the partner\'s rows alone and never '
      'moves rows into closed or partner accounts', () async {
    final groceries = await t.categoryId('Groceries');
    final old = (await t.accounts.getAccountById('old'))!;
    await t.accounts.updateAccount(old.copyWith(isClosed: true));
    for (final (id, account) in [
      ('mine', 'checking'),
      ('theirs-row', 'theirs'),
    ]) {
      await t.transactions.createTransaction(
        Transaction(
          id: id,
          accountId: account,
          amount: -100,
          date: day,
          memo: 'shop',
        ),
      );
    }

    final stats = await service.applyRulesToAllTransactions([
      rule('into-closed', const [
        RuleAction(type: RuleActionType.setAccount, value: 'old'),
      ]),
      rule('into-partner', const [
        RuleAction(type: RuleActionType.setAccount, value: 'theirs'),
      ]),
      rule('categorise', [
        RuleAction(type: RuleActionType.setCategory, value: groceries),
      ]),
    ]);

    expect(stats.modifiedCount, 1);
    final mine = (await t.transactions.getTransactionById('mine'))!;
    expect(mine.accountId, 'checking');
    expect(mine.categoryId, groceries);
    final theirs = (await t.transactions.getTransactionById('theirs-row'))!;
    expect(theirs.categoryId, isNull);
    await expectNoForeignKeyViolations(t);
  });

  test(
    '(I9) stored rules with unknown targets are applied without them',
    () async {
      await t.rules.createRule(
        rule('stale', const [
          RuleAction(type: RuleActionType.setCategory, value: 'gone'),
          RuleAction(type: RuleActionType.setPayee, value: 'gone-too'),
          RuleAction(type: RuleActionType.setMemo, value: 'kept'),
        ]),
      );
      final active = await service.loadActiveRules();
      expect(active.single.actions.map((a) => a.type), [
        RuleActionType.setMemo,
      ]);
      // The stored rule is untouched.
      expect((await t.rules.getRule('stale'))!.actions, hasLength(3));
    },
  );
}
