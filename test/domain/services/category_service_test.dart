import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/services/category_service.dart';

import '../../helpers/test_database.dart';
import 'ledger_test_helpers.dart';

/// Something on the undo stack.
class _NoopAction implements ReversibleAction {
  @override
  Future<void> undo() async {}
  @override
  Future<void> redo() async {}
}

void main() {
  late TestDatabase t;
  late CategoryService service;
  late String groceries; // deleted
  late String dining; // target

  final m1 = DateTime.utc(2026, 1);
  final m2 = DateTime.utc(2026, 2);

  Future<int> budgeted(String categoryId, DateTime month) async =>
      (await t.budgets.getBudgetByCategoryAndMonth(
        categoryId,
        CalendarDate.monthKey(month),
      ))?.budgeted ??
      0;

  setUp(() async {
    t = TestDatabase();
    service = CategoryService(
      categoryRepository: t.categories,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
    );
    groceries = await t.categoryId('Groceries');
    dining = await t.categoryId('Dining Out');

    await t.addAccount(id: 'acc', startingBalance: 500000);
    await t.payees.createPayee(
      Payee(id: 'payee', name: 'Shop', autoCategoryId: groceries),
    );
    // Income (uncategorised -> To Be Budgeted).
    await t.addTransaction(
      accountId: 'acc',
      amount: 300000,
      date: DateTime.utc(2026, 1, 2),
    );

    // Budgets: groceries in both months, the target only in the second.
    await t.budgeting.setCategoryBudgetedAmount(groceries, 40000, m1);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 30000, m2);
    await t.budgeting.setCategoryBudgetedAmount(dining, 10000, m2);

    await t.addTransaction(
      id: 'live-1',
      accountId: 'acc',
      amount: -12000,
      date: DateTime.utc(2026, 1, 15),
      categoryId: groceries,
      payeeId: 'payee',
    );
    await t.addTransaction(
      id: 'soft-deleted',
      accountId: 'acc',
      amount: -9999,
      date: DateTime.utc(2026, 1, 16),
      categoryId: groceries,
      isDeleted: true,
    );
    // Split: the parent carries the account amount, children the categories.
    await t.addTransaction(
      id: 'split',
      accountId: 'acc',
      amount: -5000,
      date: DateTime.utc(2026, 2, 3),
    );
    await t.addTransaction(
      id: 'split-groceries',
      accountId: 'acc',
      amount: -2000,
      date: DateTime.utc(2026, 2, 3),
      categoryId: groceries,
      parentTransactionId: 'split',
    );
    await t.addTransaction(
      id: 'split-dining',
      accountId: 'acc',
      amount: -3000,
      date: DateTime.utc(2026, 2, 3),
      categoryId: dining,
      parentTransactionId: 'split',
    );
    await t.addTransaction(
      id: 'live-2',
      accountId: 'acc',
      amount: -4000,
      date: DateTime.utc(2026, 2, 10),
      categoryId: groceries,
    );

    await t.scheduledTransactions.createScheduledTransaction(
      ScheduledTransaction(
        id: 'sched',
        accountId: 'acc',
        categoryId: groceries,
        amount: -1000,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2026, 3, 1),
      ),
    );
    await addParsingRows(t, id: 'parse', categoryId: groceries);
    await t.rules.createRule(
      Rule(
        id: 'rule-mixed',
        name: 'Mixed',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: const [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: 'Shop',
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
          const RuleAction(type: RuleActionType.setMemo, value: 'food'),
        ],
      ),
    );
    await t.rules.createRule(
      Rule(
        id: 'rule-only',
        name: 'Only',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: const [
          RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.contains,
            value: 'market',
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ],
      ),
    );
    await t.budgetTemplates.createTemplate(
      BudgetTemplate(
        id: 'tpl',
        name: 'Monthly',
        data: {groceries: 40000, dining: 5000},
      ),
    );

    await expectLedgerInvariant(t, m1);
    await expectLedgerInvariant(t, m2);
  });

  tearDown(() => t.close());

  Future<Map<String, dynamic>> templateData() async =>
      jsonDecode(await column(t, 'budget_templates', 'tpl', 'data') as String)
          as Map<String, dynamic>;

  test('counts live transactions only', () async {
    expect(await service.countTransactions(groceries), 3);
  });

  test('delete with target merges budgets and moves every reference', () async {
    final tbb1 = await t.budgeting.calculateTBB(m1);
    final tbb2 = await t.budgeting.calculateTBB(m2);
    final availableBoth =
        await t.budgeting.calculateCategoryAvailable(groceries, m2) +
        await t.budgeting.calculateCategoryAvailable(dining, m2);

    await service.deleteCategory(groceries, reassignTo: dining);

    expect(await t.categories.getCategoryById(groceries), isNull);
    // Budgets merged per month (target had no row in m1, one in m2).
    expect(await countRows(t, 'budgets', 'category_id = ?', [groceries]), 0);
    expect(await budgeted(dining, m1), 40000);
    expect(await budgeted(dining, m2), 40000);
    expect(await countRows(t, 'budgets', 'category_id = ?', [dining]), 2);

    // All transactions, also the soft-deleted one and the split child.
    expect(
      await countRows(t, 'transactions', 'category_id = ?', [groceries]),
      0,
    );
    for (final id in ['live-1', 'soft-deleted', 'split-groceries', 'live-2']) {
      expect(await column(t, 'transactions', id, 'category_id'), dining);
    }
    expect(await column(t, 'transactions', 'split', 'category_id'), isNull);

    expect((await t.payees.getPayeeById('payee'))!.autoCategoryId, dining);
    expect(
      (await t.scheduledTransactions.getScheduledTransactionById(
        'sched',
      ))!.categoryId,
      dining,
    );
    expect(await column(t, 'parsing_history', 'parse', 'category_id'), dining);

    final mixed = (await t.rules.getRule('rule-mixed'))!;
    expect(mixed.actions.map((a) => '${a.type.name}:${a.value}'), [
      'setCategory:$dining',
      'setMemo:food',
    ]);
    expect(mixed.isActive, isTrue);
    final only = (await t.rules.getRule('rule-only'))!;
    expect(only.actions.single.value, dining);
    expect(only.isActive, isTrue);

    expect(await templateData(), {dining: 45000});

    // To Be Budgeted unchanged; the target holds both categories' money.
    expect(await t.budgeting.calculateTBB(m1), tbb1);
    expect(await t.budgeting.calculateTBB(m2), tbb2);
    expect(
      await t.budgeting.calculateCategoryAvailable(dining, m2),
      availableBoth,
    );
    await expectLedgerInvariant(t, m1);
    await expectLedgerInvariant(t, m2);
    await expectNoForeignKeyViolations(t);
  });

  test('delete without target returns its money to To Be Budgeted', () async {
    final tbb1 = await t.budgeting.calculateTBB(m1);
    final tbb2 = await t.budgeting.calculateTBB(m2);
    final available1 = await t.budgeting.calculateCategoryAvailable(
      groceries,
      m1,
    );
    final available2 = await t.budgeting.calculateCategoryAvailable(
      groceries,
      m2,
    );
    // budgeted 40000 - 12000 in m1; + 30000 - 2000 - 4000 in m2.
    expect(available1, 28000);
    expect(available2, 52000);

    await service.deleteCategory(groceries, reassignTo: null);

    expect(await t.categories.getCategoryById(groceries), isNull);
    expect(await countRows(t, 'budgets', 'category_id = ?', [groceries]), 0);
    expect(await budgeted(dining, m2), 10000);
    expect(await budgeted(dining, m1), 0);

    for (final id in ['live-1', 'soft-deleted', 'split-groceries', 'live-2']) {
      expect(await column(t, 'transactions', id, 'category_id'), isNull);
    }
    expect(
      await column(t, 'transactions', 'split-dining', 'category_id'),
      dining,
    );

    expect((await t.payees.getPayeeById('payee'))!.autoCategoryId, isNull);
    expect(
      (await t.scheduledTransactions.getScheduledTransactionById(
        'sched',
      ))!.categoryId,
      isNull,
    );
    expect(await column(t, 'parsing_history', 'parse', 'category_id'), isNull);

    // The setCategory action is removed; a rule left without actions is
    // deactivated.
    final mixed = (await t.rules.getRule('rule-mixed'))!;
    expect(mixed.actions.map((a) => a.type), [RuleActionType.setMemo]);
    expect(mixed.isActive, isTrue);
    final only = (await t.rules.getRule('rule-only'))!;
    expect(only.actions, isEmpty);
    expect(only.isActive, isFalse);

    expect(await templateData(), {dining: 5000});

    // Budgeted money and (uncategorised) activity flow into TBB. The
    // 30000 budgeted for m2 had been taken out of m1's TBB as well (money
    // assigned ahead), so m1 gets it back too.
    expect(await t.budgeting.calculateTBB(m1), tbb1 + available1 + 30000);
    expect(await t.budgeting.calculateTBB(m2), tbb2 + available2);
    await expectLedgerInvariant(t, m1);
    await expectLedgerInvariant(t, m2);
    await expectNoForeignKeyViolations(t);
  });

  test('delete onto itself is rejected', () {
    expect(
      () => service.deleteCategory(groceries, reassignTo: groceries),
      throwsArgumentError,
    );
  });

  group('category groups', () {
    late String target;

    setUp(() async {
      target = (await t.categories.getAllCategoryGroups())
          .firstWhere((g) => g.name == 'Quality of Life')
          .id;
      await t.categories.createCategoryGroup(
        const CategoryGroup(id: 'grp', name: 'Temporary'),
      );
      await t.categories.createCategory(
        const Category(id: 'cat', name: 'Gifts', categoryGroupId: 'grp'),
      );
      await t.budgeting.setCategoryBudgetedAmount('cat', 7000, m1);
      await t.addTransaction(
        id: 'gift',
        accountId: 'acc',
        amount: -2500,
        date: DateTime.utc(2026, 1, 20),
        categoryId: 'cat',
      );
    });

    test('counts its categories', () async {
      expect(await service.countCategoriesInGroup('grp'), 1);
    });

    test('moves categories with budgets and transactions', () async {
      final tbb = await t.budgeting.calculateTBB(m2);

      await service.deleteCategoryGroup('grp', moveCategoriesTo: target);

      expect(await t.categories.getCategoryGroupById('grp'), isNull);
      final moved = (await t.categories.getCategoryById('cat'))!;
      expect(moved.categoryGroupId, target);
      expect(await budgeted('cat', m1), 7000);
      expect(await column(t, 'transactions', 'gift', 'category_id'), 'cat');
      expect(await t.budgeting.calculateCategoryAvailable('cat', m1), 4500);
      expect(await t.budgeting.calculateTBB(m2), tbb);
      await expectLedgerInvariant(t, m2);
      await expectNoForeignKeyViolations(t);
    });

    test('non-empty group without target throws and keeps data', () async {
      await expectLater(
        service.deleteCategoryGroup('grp', moveCategoriesTo: null),
        throwsA(isA<CategoryGroupNotEmptyException>()),
      );
      await expectLater(
        service.deleteCategoryGroup('grp', moveCategoriesTo: 'grp'),
        throwsA(isA<CategoryGroupNotEmptyException>()),
      );
      expect(await t.categories.getCategoryGroupById('grp'), isNotNull);
      expect(
        (await t.categories.getCategoryById('cat'))!.categoryGroupId,
        'grp',
      );
    });

    test('empty group is deleted without target', () async {
      await t.categories.createCategoryGroup(
        const CategoryGroup(id: 'empty', name: 'Empty'),
      );
      await service.deleteCategoryGroup('empty', moveCategoriesTo: null);
      expect(await t.categories.getCategoryGroupById('empty'), isNull);
      await expectNoForeignKeyViolations(t);
    });
  });

  test('(L13) deleting clears the undo stack', () async {
    final undo = UndoService()..addAction(_NoopAction());
    final withUndo = CategoryService(
      categoryRepository: t.categories,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
      undoService: undo,
    );
    expect(undo.canUndo, isTrue);
    await withUndo.deleteCategory(groceries, reassignTo: null);
    expect(undo.canUndo, isFalse);
    expect(undo.canRedo, isFalse);
  });
}
