import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/services/import/transaction_import_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../helpers/test_database.dart';

Rule _rule(
  String id, {
  required int priority,
  required List<RuleCondition> conditions,
  required List<RuleAction> actions,
  bool isActive = true,
}) => Rule(
  id: id,
  name: id,
  priority: priority,
  isActive: isActive,
  matchLogic: RuleMatchLogic.and,
  conditions: conditions,
  actions: actions,
);

ImportTransaction _row(
  int amount, {
  String? payee,
  String? memo,
  String? description,
  String? categoryId,
  DateTime? date,
}) => ImportTransaction(
  date: date ?? DateTime(2025, 3, 14, 18, 30),
  amount: amount,
  payeeName: payee,
  memo: memo,
  originalDescription: description,
  categoryId: categoryId,
);

void main() {
  late TestDatabase t;
  late TransactionImportService service;
  late String accountId;
  late String groceries;
  late String dining;

  setUp(() async {
    t = TestDatabase();
    service = TransactionImportService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      ruleMatchingService: RuleMatchingService(
        t.payees,
        t.transactions,
        t.rules,
      ),
      unitOfWork: t.unitOfWork,
    );
    accountId = (await t.addAccount(name: 'Checking')).id;
    groceries = await t.categoryId('Groceries');
    final all = await t.categories.getAllCategories();
    dining = all.firstWhere((c) => c.id != groceries).id;
  });
  tearDown(() => t.close());

  Future<List<Transaction>> imported() async =>
      (await t.transactions.getAllTransactions())
        ..sort((a, b) => a.amount.compareTo(b.amount));

  test('builds calendar-day, cleared rows and resolves payees by name '
      '(trimmed, case-insensitive)', () async {
    await t.payees.createPayee(const Payee(id: 'p-rewe', name: 'REWE'));

    final count = await service.importTransactions([
      _row(-1000, payee: '  rewe ', memo: 'weekly'),
      _row(-2000, payee: 'Bakery'),
      _row(-3000, payee: 'bakery '),
      _row(-4000),
    ], accountId);

    expect(count, 4);
    final rows = await imported();
    expect(rows, hasLength(4));
    for (final r in rows) {
      expect(r.accountId, accountId);
      expect(r.date, DateTime.utc(2025, 3, 14));
      expect(r.cleared, TransactionClearStatus.cleared);
      expect(r.approved, isTrue);
    }
    // Sorted by amount: -4000, -3000, -2000, -1000.
    expect(rows[3].payeeId, 'p-rewe');
    expect(rows[3].memo, 'weekly');
    expect(rows[2].payeeId, rows[1].payeeId);
    expect(rows[0].payeeId, isNull);
    final payees = await t.payees.getAllPayees();
    expect(payees.map((p) => p.name), unorderedEquals(['REWE', 'Bakery']));
  });

  test('regex rules on the payee name and the bank description', () async {
    await t.rules.createRule(
      _rule(
        'regex-payee',
        priority: 0,
        conditions: const [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.regex,
            value: r'^(rewe|edeka)\b',
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ],
      ),
    );
    await t.rules.createRule(
      _rule(
        'regex-description',
        priority: 1,
        conditions: const [
          RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.regex,
            value: r'card\s+\d{4}',
          ),
        ],
        actions: const [
          RuleAction(type: RuleActionType.setMemo, value: 'Card payment'),
        ],
      ),
    );

    await service.importTransactions([
      _row(-1000, payee: 'Edeka Center', description: 'CARD 1234 EDEKA'),
      _row(-2000, payee: 'My Edeka'),
    ], accountId);

    final rows = await imported();
    expect(rows[1].categoryId, groceries);
    expect(rows[1].memo, 'Card payment');
    expect(rows[0].categoryId, isNull);
    expect(rows[0].memo, isNull);
  });

  test("a rule's set-payee action is honoured", () async {
    await t.payees.createPayee(
      Payee(id: 'p-amazon', name: 'Amazon', autoCategoryId: dining),
    );
    await t.rules.createRule(
      _rule(
        'amazon',
        priority: 0,
        conditions: const [
          RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.contains,
            value: 'amzn mktp',
          ),
        ],
        actions: const [
          RuleAction(type: RuleActionType.setPayee, value: 'p-amazon'),
        ],
      ),
    );

    await service.importTransactions([
      _row(-1000, payee: 'AMZN Mktp DE*2X4', description: 'AMZN MKTP DE*2X4'),
    ], accountId);

    final row = (await imported()).single;
    expect(row.payeeId, 'p-amazon');
    // The payee of the rule supplies its default category.
    expect(row.categoryId, dining);
    // No payee was created from the raw bank name.
    expect((await t.payees.getAllPayees()).map((p) => p.id), ['p-amazon']);
  });

  test('the highest-priority (lowest number) matching rule wins per field, '
      'lower-priority rules fill the remaining fields', () async {
    final condition = RuleCondition.amount(
      operator: RuleConditionOperator.lessThan,
      minor: 0,
    );
    // Created in reverse order to show that priority, not insertion,
    // decides.
    await t.rules.createRule(
      _rule(
        'low',
        priority: 5,
        conditions: [condition],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: dining),
          const RuleAction(type: RuleActionType.setMemo, value: 'from low'),
        ],
      ),
    );
    await t.rules.createRule(
      _rule(
        'high',
        priority: 0,
        conditions: [condition],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ],
      ),
    );
    await t.rules.createRule(
      _rule(
        'inactive',
        priority: -1,
        isActive: false,
        conditions: [condition],
        actions: const [
          RuleAction(type: RuleActionType.setMemo, value: 'inactive'),
        ],
      ),
    );

    await service.importTransactions([_row(-1000, payee: 'Shop')], accountId);

    final row = (await imported()).single;
    expect(row.categoryId, groceries);
    expect(row.memo, 'from low');
  });

  test('rules take precedence over the payee default category, which is '
      'the fallback', () async {
    await t.payees.createPayee(
      Payee(id: 'p-shop', name: 'Shop', autoCategoryId: dining),
    );
    await t.rules.createRule(
      _rule(
        'big',
        priority: 0,
        conditions: [
          RuleCondition.amount(
            operator: RuleConditionOperator.lessThan,
            minor: -5000,
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ],
      ),
    );

    await service.importTransactions([
      _row(-9000, payee: 'Shop'),
      _row(-1000, payee: 'shop'),
      // A category picked in the review is kept.
      _row(-8000, payee: 'Shop', categoryId: dining),
    ], accountId);

    final rows = await imported();
    expect(rows[0].categoryId, groceries); // -9000: rule
    expect(rows[1].categoryId, dining); // -8000: picked
    expect(rows[2].categoryId, dining); // -1000: payee default
    expect(rows.every((r) => r.payeeId == 'p-shop'), isTrue);
  });

  test('the import is atomic: a failure leaves nothing behind', () async {
    await expectLater(
      service.importTransactions([
        _row(-1000, payee: 'New Payee'),
        _row(-2000, payee: 'Other Payee'),
      ], 'missing-account'),
      throwsA(anything),
    );

    expect(await t.transactions.getAllTransactions(), isEmpty);
    expect(await t.payees.getAllPayees(), isEmpty);
  });

  test('an empty list imports nothing', () async {
    expect(await service.importTransactions(const [], accountId), 0);
  });

  test('a category from the file wins over rules, rules over the payee '
      'default', () async {
    await t.payees.createPayee(
      Payee(id: 'p-shop', name: 'Shop', autoCategoryId: dining),
    );
    await t.rules.createRule(
      _rule(
        'all-shop',
        priority: 0,
        conditions: [
          const RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: 'shop',
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: groceries),
        ],
      ),
    );

    final fromFile = ImportTransaction(
      date: DateTime.utc(2025, 3, 14),
      amount: -3000,
      payeeName: 'Shop',
      categoryName: 'Dining Out',
      categoryId: dining,
    );
    final unmatched = ImportTransaction(
      date: DateTime.utc(2025, 3, 14),
      amount: -2000,
      payeeName: 'Shop',
      categoryName: 'Nope',
    );
    await service.importTransactions([fromFile, unmatched], accountId);

    final rows = await imported();
    expect(rows[0].categoryId, dining); // -3000: file category kept
    expect(rows[1].categoryId, groceries); // -2000: unmatched -> rule
  });

  test('duplicates are detected only in the chosen account and re-checked '
      'when the account changes', () async {
    final savings = (await t.addAccount(name: 'Savings')).id;
    await t.payees.createPayee(const Payee(id: 'p-rent', name: 'Rent'));
    await t.addTransaction(
      accountId: savings,
      amount: -50000,
      date: DateTime.utc(2025, 3, 1),
      payeeId: 'p-rent',
    );
    final rows = [
      ImportTransaction(
        date: DateTime.utc(2025, 3, 1),
        amount: -50000,
        payeeName: 'Rent',
      ),
      ImportTransaction(
        date: DateTime.utc(2025, 3, 2),
        amount: -100,
        payeeName: 'Kiosk',
      ),
    ];

    await service.markDuplicates(rows, accountId);
    expect(rows.map((r) => r.isDuplicate), [false, false]);

    await service.markDuplicates(rows, savings);
    expect(rows.map((r) => r.isDuplicate), [true, false]);
    expect(rows.first.isSelected, isFalse);

    await service.markDuplicates(rows, accountId);
    expect(rows.map((r) => r.isDuplicate), [false, false]);
    expect(rows.first.isSelected, isTrue);
  });
}
