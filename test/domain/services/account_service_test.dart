import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/services/account_service.dart';

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
  late AccountService service;
  late String groceries;

  final month = DateTime.utc(2026, 3);
  final day = DateTime.utc(2026, 3, 10);

  setUp(() async {
    t = TestDatabase();
    service = AccountService(
      accountRepository: t.accounts,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
    );
    groceries = await t.categoryId('Groceries');

    await t.addAccount(id: 'a', name: 'Checking', startingBalance: 100000);
    await t.addAccount(id: 'b', name: 'Savings', startingBalance: 50000);
    await t.addAccount(id: 'c', name: 'Cash', startingBalance: 2000);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 20000, month);

    // Transfers into and out of b (the account to delete).
    await addTransfer(
      t,
      id: 'a-to-b',
      from: 'a',
      to: 'b',
      amount: 10000,
      date: day,
    );
    await addTransfer(
      t,
      id: 'b-to-a',
      from: 'b',
      to: 'a',
      amount: 2500,
      date: day,
    );
    await addTransfer(
      t,
      id: 'c-to-b',
      from: 'c',
      to: 'b',
      amount: 700,
      date: day,
    );
    // A soft-deleted transfer pair between a and b.
    await addTransfer(
      t,
      id: 'deleted',
      from: 'a',
      to: 'b',
      amount: 999,
      date: day,
      isDeleted: true,
    );
    // A transfer that does not involve b stays a transfer.
    await addTransfer(
      t,
      id: 'a-to-c',
      from: 'a',
      to: 'c',
      amount: 300,
      date: day,
    );

    // b: split, categorised and soft-deleted rows.
    await t.addTransaction(
      id: 'b-split',
      accountId: 'b',
      amount: -3000,
      date: day,
    );
    await t.addTransaction(
      id: 'b-split-1',
      accountId: 'b',
      amount: -1000,
      date: day,
      categoryId: groceries,
      parentTransactionId: 'b-split',
    );
    await t.addTransaction(
      id: 'b-split-2',
      accountId: 'b',
      amount: -2000,
      date: day,
      parentTransactionId: 'b-split',
    );
    await t.addTransaction(
      id: 'b-groceries',
      accountId: 'b',
      amount: -4000,
      date: day,
      categoryId: groceries,
    );
    await t.addTransaction(
      id: 'b-soft-deleted',
      accountId: 'b',
      amount: -123,
      date: day,
      isDeleted: true,
    );
    await t.addTransaction(
      id: 'a-groceries',
      accountId: 'a',
      amount: -1500,
      date: day,
      categoryId: groceries,
    );

    await t.scheduledTransactions.createScheduledTransaction(
      ScheduledTransaction(
        id: 'sched-b',
        accountId: 'b',
        amount: -500,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2026, 4, 1),
      ),
    );
    await t.scheduledTransactions.createScheduledTransaction(
      ScheduledTransaction(
        id: 'sched-a',
        accountId: 'a',
        amount: -500,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2026, 4, 1),
      ),
    );
    await t.payees.createPayee(
      const Payee(id: 'payee', name: 'Bank', defaultAccountId: 'b'),
    );
    await t.rules.createRule(
      const Rule(
        id: 'rule',
        name: 'Move to savings',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.equals,
            value: 'Bank',
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setAccount, value: 'b'),
          RuleAction(type: RuleActionType.markCleared, value: 'true'),
        ],
      ),
    );

    await expectLedgerInvariant(t, month);
  });

  tearDown(() => t.close());

  test('setClosed closes and reopens without touching history', () async {
    await service.setClosed('b', true);
    expect((await t.accounts.getAccountById('b'))!.isClosed, isTrue);
    expect(await countRows(t, 'transactions', 'account_id = ?', ['b']), 9);
    await service.setClosed('b', false);
    expect((await t.accounts.getAccountById('b'))!.isClosed, isFalse);
  });

  test('deleteAccount removes the account and converts transfers', () async {
    final converted = await service.deleteAccount('b');

    // Three live legs in other accounts pointed at b.
    expect(converted, 3);
    expect(await t.accounts.getAccountById('b'), isNull);
    expect(await countRows(t, 'transactions', 'account_id = ?', ['b']), 0);
    expect(
      await countRows(t, 'transactions', 'transfer_account_id = ?', ['b']),
      0,
    );

    for (final id in ['a-to-b-out', 'b-to-a-in', 'c-to-b-out', 'deleted-out']) {
      expect(
        await column(t, 'transactions', id, 'transfer_account_id'),
        isNull,
      );
      expect(
        await column(t, 'transactions', id, 'transfer_transaction_id'),
        isNull,
      );
      expect(await column(t, 'transactions', id, 'category_id'), isNull);
    }
    // Untouched transfer between a and c.
    expect(
      await column(t, 'transactions', 'a-to-c-out', 'transfer_account_id'),
      'c',
    );
    expect(
      await column(t, 'transactions', 'a-to-c-in', 'transfer_transaction_id'),
      'a-to-c-out',
    );

    expect(
      await t.scheduledTransactions.getScheduledTransactionById('sched-b'),
      isNull,
    );
    expect(
      await t.scheduledTransactions.getScheduledTransactionById('sched-a'),
      isNotNull,
    );
    expect((await t.payees.getPayeeById('payee'))!.defaultAccountId, isNull);
    final rule = (await t.rules.getRule('rule'))!;
    expect(rule.actions.map((a) => a.type), [RuleActionType.markCleared]);
    expect(rule.isActive, isTrue);

    await expectLedgerInvariant(t, month);
    await expectNoForeignKeyViolations(t);
  });

  test('converted transfer legs count towards To Be Budgeted', () async {
    final before = await t.budgeting.calculateTBB(month);
    // b's own budget-relevant contributions: starting balance and its
    // uncategorised non-transfer, non-split-parent rows (split child 2).
    const bStart = 50000;
    const bUncategorised = -2000;

    await service.deleteAccount('b');

    // Converted legs: a -10000, a +2500, c -700.
    const convertedLegs = -10000 + 2500 - 700;
    expect(
      await t.budgeting.calculateTBB(month),
      before - bStart - bUncategorised + convertedLegs,
    );
    await expectLedgerInvariant(t, month);
  });

  test('a rule left without actions is deactivated', () async {
    await t.rules.createRule(
      const Rule(
        id: 'only',
        name: 'Only account',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [],
        actions: [RuleAction(type: RuleActionType.setAccount, value: 'b')],
      ),
    );
    await service.deleteAccount('b');
    final rule = (await t.rules.getRule('only'))!;
    expect(rule.actions, isEmpty);
    expect(rule.isActive, isFalse);
  });

  test('(L13) deleting clears the undo stack', () async {
    final undo = UndoService()..addAction(_NoopAction());
    final withUndo = AccountService(
      accountRepository: t.accounts,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
      undoService: undo,
    );
    expect(undo.canUndo, isTrue);
    await withUndo.deleteAccount('c');
    expect(undo.canUndo, isFalse);
    expect(undo.canRedo, isFalse);
  });
}
