import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

import '../../helpers/test_database.dart';

/// Budget invariant for [month]:
///
/// SUM(available of every category) + To Be Budgeted
///   == SUM over accounts of (starting balance + non-deleted,
///      non-split-child rows dated before the next month).
Future<void> expectLedgerInvariant(TestDatabase t, DateTime month) async {
  final categories = await t.categories.getAllCategories();
  var available = 0;
  for (final c in categories) {
    available += await t.budgeting.calculateCategoryAvailable(c.id, month);
  }
  final tbb = await t.budgeting.calculateTBB(month);
  final row = await t.db
      .customSelect(
        'SELECT COALESCE((SELECT SUM(starting_balance) FROM accounts), 0) + '
        'COALESCE((SELECT SUM(amount) FROM transactions WHERE is_deleted = 0 '
        'AND parent_transaction_id IS NULL AND date < ?), 0) AS total',
        variables: [Variable.withDateTime(CalendarDate.endOfMonthUtc(month))],
      )
      .getSingle();
  expect(
    available + tbb,
    row.read<int>('total'),
    reason: 'SUM(available) + TBB must equal SUM(balances) for $month',
  );
}

/// No foreign key of the database is violated.
Future<void> expectNoForeignKeyViolations(TestDatabase t) async {
  final rows = await t.db.customSelect('PRAGMA foreign_key_check').get();
  expect(rows.map((r) => r.data).toList(), isEmpty);
}

/// A column of a row, read with raw SQL (also sees soft-deleted rows).
Future<Object?> column(
  TestDatabase t,
  String table,
  String id,
  String column,
) async {
  final row = await t.db
      .customSelect(
        'SELECT $column AS v FROM $table WHERE id = ?',
        variables: [Variable.withString(id)],
      )
      .getSingleOrNull();
  return row?.data['v'];
}

/// Number of rows of [table] matching [where] (raw SQL).
Future<int> countRows(
  TestDatabase t,
  String table,
  String where, [
  List<Object> args = const [],
]) async {
  final row = await t.db
      .customSelect(
        'SELECT COUNT(*) AS c FROM $table WHERE $where',
        variables: [
          for (final a in args)
            a is int ? Variable.withInt(a) : Variable.withString('$a'),
        ],
      )
      .getSingle();
  return row.read<int>('c');
}

/// Inserts a parsing history row (raw SQL; there is no repository for it in
/// the test helper).
Future<void> addParsingRows(
  TestDatabase t, {
  required String id,
  String? categoryId,
  String? payeeId,
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  await t.db.customStatement(
    'INSERT INTO parsing_history (id, input, payee_id, category_id, created_at) '
    'VALUES (?, ?, ?, ?, ?)',
    [id, 'input-$id', payeeId, categoryId, now],
  );
}

/// Creates a transfer pair between [from] (outflow) and [to] (inflow).
Future<(Transaction, Transaction)> addTransfer(
  TestDatabase t, {
  required String id,
  required String from,
  required String to,
  required int amount,
  required DateTime date,
  bool isDeleted = false,
}) async {
  final out = await t.addTransaction(
    id: '$id-out',
    accountId: from,
    amount: -amount,
    date: date,
    transferAccountId: to,
    transferTransactionId: '$id-in',
    isDeleted: isDeleted,
  );
  final inflow = await t.addTransaction(
    id: '$id-in',
    accountId: to,
    amount: amount,
    date: date,
    transferAccountId: from,
    transferTransactionId: '$id-out',
    isDeleted: isDeleted,
  );
  return (out, inflow);
}

/// Payee fixture shared with the controller test: payee `source` is used
/// by a live, a soft-deleted and a split-child transaction, a scheduled
/// transaction, a parsing rule/history row and two rules.
Future<void> seedPayeeReferences(TestDatabase t) async {
  final day = DateTime.utc(2026, 5, 4);
  await t.addAccount(id: 'acc', startingBalance: 10000);
  await t.payees.createPayee(const Payee(id: 'source', name: 'Shop Inc'));
  await t.payees.createPayee(const Payee(id: 'target', name: 'Shop'));
  await t.addTransaction(
    id: 'live',
    accountId: 'acc',
    amount: -1000,
    date: day,
    payeeId: 'source',
  );
  await t.addTransaction(
    id: 'soft-deleted',
    accountId: 'acc',
    amount: -2000,
    date: day,
    payeeId: 'source',
    isDeleted: true,
  );
  await t.addTransaction(
    id: 'split',
    accountId: 'acc',
    amount: -500,
    date: day,
    payeeId: 'target',
  );
  await t.addTransaction(
    id: 'split-child',
    accountId: 'acc',
    amount: -500,
    date: day,
    payeeId: 'source',
    parentTransactionId: 'split',
  );
  await t.scheduledTransactions.createScheduledTransaction(
    ScheduledTransaction(
      id: 'sched',
      accountId: 'acc',
      payeeId: 'source',
      amount: -300,
      frequency: RecurrenceFrequency.monthly,
      interval: 1,
      nextDate: DateTime.utc(2026, 6, 1),
    ),
  );
  await addParsingRows(t, id: 'parse', payeeId: 'source');
  await t.rules.createRule(
    const Rule(
      id: 'rule-mixed',
      name: 'Mixed',
      priority: 0,
      isActive: true,
      matchLogic: RuleMatchLogic.and,
      conditions: [],
      actions: [
        RuleAction(type: RuleActionType.setPayee, value: 'source'),
        RuleAction(type: RuleActionType.setMemo, value: 'shop'),
      ],
    ),
  );
  await t.rules.createRule(
    const Rule(
      id: 'rule-only',
      name: 'Only',
      priority: 1,
      isActive: true,
      matchLogic: RuleMatchLogic.and,
      conditions: [],
      actions: [RuleAction(type: RuleActionType.setPayee, value: 'source')],
    ),
  );
}

const sourceTransactionIds = ['live', 'soft-deleted', 'split-child'];

/// Every reference to `source` now points at [expected] (`null`: cleared).
Future<void> expectPayeeReferences(TestDatabase t, String? expected) async {
  expect(await t.payees.getPayeeById('source'), isNull);
  expect(await countRows(t, 'transactions', 'payee_id = ?', ['source']), 0);
  for (final id in sourceTransactionIds) {
    expect(await column(t, 'transactions', id, 'payee_id'), expected);
  }
  expect(await column(t, 'transactions', 'split', 'payee_id'), 'target');
  expect(
    (await t.scheduledTransactions.getScheduledTransactionById(
      'sched',
    ))!.payeeId,
    expected,
  );
  expect(await column(t, 'parsing_history', 'parse', 'payee_id'), expected);

  final mixed = (await t.rules.getRule('rule-mixed'))!;
  final only = (await t.rules.getRule('rule-only'))!;
  if (expected == null) {
    expect(mixed.actions.map((a) => a.type), [RuleActionType.setMemo]);
    expect(mixed.isActive, isTrue);
    expect(only.actions, isEmpty);
    expect(only.isActive, isFalse);
  } else {
    expect(mixed.actions.first.value, expected);
    expect(only.actions.single.value, expected);
    expect(only.isActive, isTrue);
  }
  await expectNoForeignKeyViolations(t);
}

/// Month of the sample ledger written by [seedSampleLedger].
final sampleLedgerMonth = DateTime.utc(2024, 3);

/// A small but complete ledger in [sampleLedgerMonth]: three accounts (one
/// credit), income, categorised spending, a transfer, a split and budgets.
Future<void> seedSampleLedger(TestDatabase t) async {
  final service = TransactionService(
    transactionRepository: t.transactions,
    payeeRepository: t.payees,
    undoService: UndoService(),
    unitOfWork: t.unitOfWork,
  );
  final groceries = await t.categoryId('Groceries');
  final dining = await t.categoryId('Dining Out');
  final checking = (await t.addAccount(
    name: 'Checking',
    startingBalance: 100000,
  )).id;
  final savings = (await t.addAccount(name: 'Savings')).id;
  final card = (await t.addAccount(
    name: 'Card',
    type: AccountType.credit,
    startingBalance: -30000,
  )).id;
  DateTime day(int d) => DateTime.utc(2024, 3, d);
  for (final input in [
    TransactionInput(
      accountId: checking,
      date: day(1),
      amount: 250000,
      newPayeeName: 'Employer',
    ),
    TransactionInput(
      accountId: checking,
      date: day(3),
      amount: -12345,
      categoryId: groceries,
      newPayeeName: 'Market',
      memo: 'Weekly shop',
    ),
    TransactionInput(
      accountId: card,
      date: day(4),
      amount: -4250,
      categoryId: dining,
      newPayeeName: 'Pizzeria',
    ),
    TransactionInput(
      accountId: checking,
      date: day(5),
      amount: -50000,
      transferAccountId: savings,
    ),
    TransactionInput(
      accountId: checking,
      date: day(6),
      amount: -9000,
      newPayeeName: 'Department Store',
      splits: [
        SplitLineInput(amount: -6000, categoryId: groceries),
        SplitLineInput(amount: -3000, categoryId: dining),
      ],
    ),
  ]) {
    await service.save(input);
  }
  await t.budgeting.setCategoryBudgetedAmount(
    groceries,
    30000,
    sampleLedgerMonth,
  );
  await t.budgeting.setCategoryBudgetedAmount(dining, 10000, sampleLedgerMonth);
}

/// What the user sees of a ledger for [month], keyed by names (so two
/// databases with different ids compare equal): account balances, every
/// category's available amount and To Be Budgeted.
Future<Map<String, Object>> ledgerFingerprint(
  TestDatabase t,
  DateTime month,
) async {
  final accounts = await t.accounts.getAllAccounts();
  final categories = await t.categories.getAllCategories();
  return {
    'balances': {for (final a in accounts) a.name: a.balance},
    'available': {
      for (final c in categories)
        c.name: await t.budgeting.calculateCategoryAvailable(c.id, month),
    },
    'tbb': await t.budgeting.calculateTBB(month),
  };
}
