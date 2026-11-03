// Rule matching against a real database: reference checks and
// "apply to all" on the whole ledger.
import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart' show AppDatabase;
import 'package:ledger_zero/domain/entities/payee.dart';
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
  group('ledger invariants of "apply to all"', () {
    Future<Transaction> row(String id) async =>
        (await t.transactions.getTransactionById(id))!;

    Future<void> add(
      String id,
      String account, {
      TransactionClearStatus cleared = TransactionClearStatus.uncleared,
      String? categoryId,
    }) => t.transactions.createTransaction(
      Transaction(
        id: id,
        accountId: account,
        amount: -100,
        date: day,
        memo: 'shop',
        cleared: cleared,
        categoryId: categoryId,
      ),
    );

    test('a reconciled row is not moved to another account (its other '
        'fields still change)', () async {
      final groceries = await t.categoryId('Groceries');
      await add(
        'reconciled',
        'checking',
        cleared: TransactionClearStatus.reconciled,
      );
      await add('open', 'checking');

      final stats = await service.applyRulesToAllTransactions([
        rule('move', [
          const RuleAction(type: RuleActionType.setAccount, value: 'old'),
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ]),
      ]);

      expect(stats.modifiedCount, 2);
      expect(stats.skippedReconciledCount, 1);
      expect(stats.skippedCount, 1);
      final reconciled = await row('reconciled');
      expect(reconciled.accountId, 'checking');
      expect(reconciled.cleared, TransactionClearStatus.reconciled);
      expect(reconciled.categoryId, groceries);
      expect((await row('open')).accountId, 'old');
    });

    test('no row moves into an account with another currency', () async {
      await t.addAccount(id: 'euro', name: 'Euro', currency: 'EUR');
      await add('usd-row', 'checking');

      final stats = await service.applyRulesToAllTransactions([
        rule('to-euro', const [
          RuleAction(type: RuleActionType.setAccount, value: 'euro'),
          RuleAction(type: RuleActionType.setMemo, value: 'shop (moved)'),
        ]),
      ]);

      expect(stats.skippedCurrencyCount, 1);
      final moved = await row('usd-row');
      expect(moved.accountId, 'checking');
      // The memo action is independent of the refused move.
      expect(moved.memo, 'shop (moved)');
    });

    test('rows of off-budget accounts get no category; a row moved into one '
        'loses it', () async {
      final groceries = await t.categoryId('Groceries');
      final dining = await t.categoryId('Dining Out');
      await t.addAccount(id: 'savings', name: 'Savings', onBudget: false);
      await add('tracked', 'savings');
      await add('budgeted', 'checking', categoryId: dining);

      final stats = await service.applyRulesToAllTransactions([
        rule('categorise', [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ]),
      ]);
      expect(stats.skippedOffBudgetCount, 1);
      expect((await row('tracked')).categoryId, isNull);
      expect((await row('budgeted')).categoryId, groceries);

      final moved = await service.applyRulesToAllTransactions([
        rule('to-savings', const [
          RuleAction(type: RuleActionType.setAccount, value: 'savings'),
        ]),
      ]);
      expect(moved.skippedCount, 0);
      final budgeted = await row('budgeted');
      expect(budgeted.accountId, 'savings');
      expect(budgeted.categoryId, isNull);
      await expectNoForeignKeyViolations(t);
    });

    test('transfer legs keep their account and stay uncategorised', () async {
      final groceries = await t.categoryId('Groceries');
      await t.addTransaction(
        id: 'leg-a',
        accountId: 'checking',
        amount: -100,
        date: day,
        transferAccountId: 'old',
        transferTransactionId: 'leg-b',
      );
      await t.addTransaction(
        id: 'leg-b',
        accountId: 'old',
        amount: 100,
        date: day,
        transferAccountId: 'checking',
        transferTransactionId: 'leg-a',
      );
      await t.db.customStatement(
        "UPDATE transactions SET memo = 'shop' WHERE id IN ('leg-a', 'leg-b')",
      );

      final stats = await service.applyRulesToAllTransactions([
        rule('all', [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
          const RuleAction(type: RuleActionType.setAccount, value: 'theirs'),
        ]),
      ]);

      expect(stats.modifiedCount, 0);
      expect((await row('leg-a')).accountId, 'checking');
      expect((await row('leg-a')).categoryId, isNull);
      expect((await row('leg-b')).accountId, 'old');
    });
  });

  test(
    '"apply to all" reads payees and split parents once, not per row',
    () async {
      final counter = _SelectCounter();
      final counted = TestDatabase.wrap(
        AppDatabase(NativeDatabase.memory().interceptWith(counter)),
      );
      addTearDown(counted.close);
      final countedService = RuleMatchingService(
        counted.payees,
        counted.transactions,
        counted.rules,
        counted.categories,
        counted.accounts,
        counted.unitOfWork,
      );
      await counted.addAccount(id: 'checking', name: 'Checking');
      final groceries = await counted.categoryId('Groceries');
      for (var p = 0; p < 20; p++) {
        await counted.payees.createPayee(Payee(id: 'p$p', name: 'Shop $p'));
      }
      const rows = 400;
      for (var i = 0; i < rows; i++) {
        await counted.addTransaction(
          id: 'tx$i',
          accountId: 'checking',
          amount: -100 - i,
          date: day,
          payeeId: 'p${i % 20}',
        );
      }
      // Ten splits of two lines each.
      for (var i = 0; i < 10; i++) {
        for (final line in ['a', 'b']) {
          await counted.addTransaction(
            id: 'tx$i-$line',
            accountId: 'checking',
            amount: -1,
            date: day,
            parentTransactionId: 'tx$i',
          );
        }
      }
      final payeeRule = Rule(
        id: 'r',
        name: 'Shop 3',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: const [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.equals,
            value: 'shop 3',
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ],
      );

      counter.selects = 0;
      final stopwatch = Stopwatch()..start();
      final stats = await countedService.applyRulesToAllTransactions([
        payeeRule,
      ]);
      stopwatch.stop();

      expect(stats.processedCount, rows + 20);
      // tx3 is a split parent: it never gets a category.
      expect(stats.modifiedCount, rows ~/ 20 - 1);
      expect(
        (await counted.transactions.getTransactionById('tx23'))!.categoryId,
        groceries,
      );
      expect(
        (await counted.transactions.getTransactionById('tx3'))!.categoryId,
        isNull,
      );
      // A handful of reads in total (rule targets, accounts, payees, the
      // rows), independent of the number of rows.
      expect(counter.selects, lessThan(20));
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    },
  );
}

/// Counts the SELECT statements run against the database.
class _SelectCounter extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return super.runSelect(executor, statement, args);
  }
}
