import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';

/// Amount equals -50.00.
const _amountIsMinus50 = RuleCondition(
  type: RuleConditionType.amount,
  operator: RuleConditionOperator.equals,
  value: '-5000',
);

void main() {
  late RuleMatchingService service;
  late MockPayeeRepository mockPayeeRepository;
  late MockTransactionRepository mockTransactionRepository;

  final testTransaction = Transaction(
    id: '1',
    accountId: 'acc1',
    date: DateTime.now(),
    amount: -5000,
    memo: 'Grocery Store Trip',
    payeeId: 'payee1',
    categoryId: null,
    cleared: TransactionClearStatus.uncleared,
    approved: false,
    isDeleted: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testPayee = Payee(
    id: 'payee1',
    name: 'Grocery Store',
    createdAt: DateTime.now(),
    isFavorite: false,
  );

  setUp(() {
    mockPayeeRepository = MockPayeeRepository();
    mockTransactionRepository = MockTransactionRepository();
    service = RuleMatchingService(
      mockPayeeRepository,
      mockTransactionRepository,
    );
    when(mockPayeeRepository.getPayeeById(any)).thenAnswer((_) async => null);
    when(
      mockPayeeRepository.getPayeeById('payee1'),
    ).thenAnswer((_) async => testPayee);
  });

  group('RuleMatchingService', () {
    test('matches payee correctly', () async {
      when(
        mockPayeeRepository.getPayeeById('payee1'),
      ).thenAnswer((_) async => testPayee);

      const rule = Rule(
        id: 'r1',
        name: 'Payee Rule',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: 'Grocery',
          ),
        ],
        actions: [RuleAction(type: RuleActionType.setMemo, value: 'Matched')],
      );

      final result = await service.applyRules([testTransaction], [rule]);
      expect(result.first.memo, 'Matched');
    });

    test('matches amount correctly (less than)', () async {
      const rule = Rule(
        id: 'r2',
        name: 'Amount Rule',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.amount,
            operator: RuleConditionOperator.lessThan,
            value: '-4000', // minor units: -50.00 < -40.00
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setMemo, value: 'Big Expense'),
        ],
      );

      final result = await service.applyRules([testTransaction], [rule]);
      expect(result.first.memo, 'Big Expense');
    });

    test('matches description correctly (contains)', () async {
      const rule = Rule(
        id: 'r3',
        name: 'Desc Rule',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.contains,
            value: 'Store',
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setMemo, value: 'Store Found'),
        ],
      );

      final result = await service.applyRules([testTransaction], [rule]);
      expect(result.first.memo, 'Store Found');
    });

    test('applies actions correctly', () async {
      const rule = Rule(
        id: 'r4',
        name: 'Action Rule',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.amount,
            operator: RuleConditionOperator.equals,
            value: '-5000', // minor units
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: 'cat1'),
          RuleAction(type: RuleActionType.markApproved, value: 'true'),
        ],
      );

      final result = await service.applyRules([testTransaction], [rule]);
      expect(result.first.categoryId, 'cat1');
      expect(result.first.approved, true);
    });

    test('respects priority: the highest-priority (lowest number) matching '
        'rule wins per field', () async {
      const rule1 = Rule(
        id: 'r1',
        name: 'Rule 1',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [_amountIsMinus50],
        actions: [RuleAction(type: RuleActionType.setMemo, value: 'Rule1')],
      );
      const rule2 = Rule(
        id: 'r2',
        name: 'Rule 2',
        priority: 2,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [_amountIsMinus50],
        actions: [
          RuleAction(type: RuleActionType.setMemo, value: 'Rule2'),
          RuleAction(type: RuleActionType.setCategory, value: 'cat2'),
        ],
      );

      // Rule 1 (priority 1) beats rule 2 (priority 2) for the memo,
      // whatever the list order; rule 2 still sets the category, which no
      // higher-priority rule touched.
      for (final rules in [
        [rule2, rule1],
        [rule1, rule2],
      ]) {
        final result = await service.applyRules([testTransaction], rules);
        expect(result.first.memo, 'Rule1');
        expect(result.first.categoryId, 'cat2');
      }

      // Swapping the priorities swaps the winner.
      final result2 = await service.applyRules(
        [testTransaction],
        [rule1.copyWith(priority: 10), rule2.copyWith(priority: 0)],
      );
      expect(result2.first.memo, 'Rule2');
    });

    test('priority 0 is the highest priority; equal priorities keep the '
        'list order', () async {
      Rule memoRule(String id, int priority) => Rule(
        id: id,
        name: id,
        priority: priority,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: const [_amountIsMinus50],
        actions: [RuleAction(type: RuleActionType.setMemo, value: id)],
      );

      final top = await service.apply(testTransaction, [
        memoRule('five', 5),
        memoRule('zero', 0),
      ]);
      expect(top.memo, 'zero');

      final tie = await service.apply(testTransaction, [
        memoRule('first', 3),
        memoRule('second', 3),
      ]);
      expect(tie.memo, 'first');
    });

    test('inactive rules and rules without conditions are ignored', () async {
      const inactive = Rule(
        id: 'off',
        name: 'Off',
        priority: 0,
        isActive: false,
        matchLogic: RuleMatchLogic.and,
        conditions: [_amountIsMinus50],
        actions: [RuleAction(type: RuleActionType.setMemo, value: 'off')],
      );
      const noConditions = Rule(
        id: 'empty',
        name: 'Empty',
        priority: 1,
        isActive: true,
        matchLogic: RuleMatchLogic.or,
        conditions: [],
        actions: [RuleAction(type: RuleActionType.setMemo, value: 'empty')],
      );
      const active = Rule(
        id: 'on',
        name: 'On',
        priority: 2,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [_amountIsMinus50],
        actions: [RuleAction(type: RuleActionType.setMemo, value: 'on')],
      );

      final result = await service.apply(testTransaction, [
        inactive,
        noConditions,
        active,
      ]);
      expect(result.memo, 'on');
    });

    group('regex conditions', () {
      Rule regexRule(RuleConditionType type, String pattern) => Rule(
        id: 'rx',
        name: 'Regex',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: type,
            operator: RuleConditionOperator.regex,
            value: pattern,
          ),
        ],
        actions: const [
          RuleAction(type: RuleActionType.setCategory, value: 'cat-rx'),
        ],
      );

      test('match case-insensitively on payee and description', () async {
        final payee = await service.apply(testTransaction, [
          regexRule(RuleConditionType.payee, r'^grocery\s+st'),
        ]);
        expect(payee.categoryId, 'cat-rx');

        final description = await service.apply(testTransaction, [
          regexRule(RuleConditionType.description, r'store\s+TRIP$'),
        ]);
        expect(description.categoryId, 'cat-rx');
      });

      test('a non-matching or invalid pattern does not match', () async {
        final noMatch = await service.apply(testTransaction, [
          regexRule(RuleConditionType.payee, r'^store'),
        ]);
        expect(noMatch.categoryId, isNull);

        final invalid = await service.apply(testTransaction, [
          regexRule(RuleConditionType.payee, r'([unclosed'),
        ]);
        expect(invalid.categoryId, isNull);
      });
    });

    test(
      'payeeName hint is used for rows whose payee does not exist yet',
      () async {
        const rule = Rule(
          id: 'p',
          name: 'Payee',
          priority: 0,
          isActive: true,
          matchLogic: RuleMatchLogic.and,
          conditions: [
            RuleCondition(
              type: RuleConditionType.payee,
              operator: RuleConditionOperator.equals,
              value: 'new shop',
            ),
          ],
          actions: [RuleAction(type: RuleActionType.setCategory, value: 'c1')],
        );
        final withoutPayee = Transaction(
          id: 'new',
          accountId: 'acc1',
          date: DateTime.utc(2025, 1, 1),
          amount: -5000,
        );

        final hinted = await service.apply(withoutPayee, [
          rule,
        ], payeeName: 'New Shop');
        expect(hinted.categoryId, 'c1');

        final unhinted = await service.apply(withoutPayee, [rule]);
        expect(unhinted.categoryId, isNull);
      },
    );

    test('description hint is matched in addition to the memo', () async {
      const rule = Rule(
        id: 'd',
        name: 'Desc',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.startsWith,
            value: 'sepa ',
          ),
        ],
        actions: [RuleAction(type: RuleActionType.setCategory, value: 'c2')],
      );

      final hinted = await service.apply(testTransaction, [
        rule,
      ], description: 'SEPA Lastschrift 123');
      expect(hinted.categoryId, 'c2');

      final unhinted = await service.apply(testTransaction, [rule]);
      expect(unhinted.categoryId, isNull);
    });
  });

  group('RuleApplyMode', () {
    // A rule that sets every field.
    const everything = Rule(
      id: 'all',
      name: 'All',
      priority: 0,
      isActive: true,
      matchLogic: RuleMatchLogic.and,
      conditions: [_amountIsMinus50],
      actions: [
        RuleAction(type: RuleActionType.setCategory, value: 'rule-cat'),
        RuleAction(type: RuleActionType.setPayee, value: 'rule-payee'),
        RuleAction(type: RuleActionType.setMemo, value: 'rule memo'),
        RuleAction(type: RuleActionType.setAccount, value: 'rule-account'),
        RuleAction(type: RuleActionType.markCleared, value: 'true'),
        RuleAction(type: RuleActionType.markApproved, value: 'true'),
      ],
    );

    // Category, payee and memo already set.
    final filled = Transaction(
      id: 'f',
      accountId: 'acc1',
      date: DateTime.utc(2025, 1, 1),
      amount: -5000,
      payeeId: 'payee1',
      categoryId: 'user-cat',
      memo: 'user memo',
      approved: false,
    );

    // Nothing optional set.
    final empty = Transaction(
      id: 'e',
      accountId: 'acc1',
      date: DateTime.utc(2025, 1, 1),
      amount: -5000,
      approved: false,
    );

    test('suggest fills empty category/payee/memo only and never touches '
        'account, cleared or approved', () async {
      final kept = await service.apply(filled, [
        everything,
      ], mode: RuleApplyMode.suggest);
      expect(kept.categoryId, 'user-cat');
      expect(kept.payeeId, 'payee1');
      expect(kept.memo, 'user memo');
      expect(kept.accountId, 'acc1');
      expect(kept.cleared, TransactionClearStatus.uncleared);
      expect(kept.approved, isFalse);

      final filledIn = await service.apply(empty, [
        everything,
      ], mode: RuleApplyMode.suggest);
      expect(filledIn.categoryId, 'rule-cat');
      expect(filledIn.payeeId, 'rule-payee');
      expect(filledIn.memo, 'rule memo');
      expect(filledIn.accountId, 'acc1');
      expect(filledIn.cleared, TransactionClearStatus.uncleared);
      expect(filledIn.approved, isFalse);
    });

    test('automatic fills empty fields and applies cleared/approved, but '
        'never moves the account', () async {
      final kept = await service.apply(filled, [
        everything,
      ], mode: RuleApplyMode.automatic);
      expect(kept.categoryId, 'user-cat');
      expect(kept.payeeId, 'payee1');
      expect(kept.memo, 'user memo');
      expect(kept.accountId, 'acc1');
      expect(kept.cleared, TransactionClearStatus.cleared);
      expect(kept.approved, isTrue);

      final filledIn = await service.apply(empty, [
        everything,
      ], mode: RuleApplyMode.automatic);
      expect(filledIn.categoryId, 'rule-cat');
      expect(filledIn.payeeId, 'rule-payee');
      expect(filledIn.memo, 'rule memo');
      expect(filledIn.accountId, 'acc1');
    });

    test('overwrite applies every action', () async {
      final result = await service.apply(filled, [
        everything,
      ], mode: RuleApplyMode.overwrite);
      expect(result.categoryId, 'rule-cat');
      expect(result.payeeId, 'rule-payee');
      expect(result.memo, 'rule memo');
      expect(result.accountId, 'rule-account');
      expect(result.cleared, TransactionClearStatus.cleared);
      expect(result.approved, isTrue);
    });

    test('transfer legs never get a category or payee', () async {
      final leg = empty.copyWith(transferAccountId: 'acc2');
      final result = await service.apply(leg, [everything]);
      expect(result.categoryId, isNull);
      expect(result.payeeId, isNull);
      expect(result.memo, 'rule memo');
    });
  });

  group('RuleCondition amount JSON', () {
    test('legacy major-unit values are read as minor units', () {
      final legacy = RuleCondition.fromJson({
        'type': 'amount',
        'operator': 'lessThan',
        'value': '5.00',
      });
      expect(legacy.amountMinor, 500);
      expect(legacy.toJson()['amountUnit'], 'minor');
    });

    test('minor-unit JSON round-trips unchanged', () {
      final condition = RuleCondition.amount(
        operator: RuleConditionOperator.greaterThan,
        minor: -1250,
      );
      final decoded = RuleCondition.fromJson(condition.toJson());
      expect(decoded.amountMinor, -1250);
      expect(decoded.value, '-1250');
    });
  });
}
