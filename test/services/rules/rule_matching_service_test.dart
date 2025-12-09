import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late RuleMatchingService service;
  late MockPayeeRepository mockPayeeRepository;
  late MockTransactionRepository mockTransactionRepository;

  setUp(() {
    mockPayeeRepository = MockPayeeRepository();
    mockTransactionRepository = MockTransactionRepository();
    service = RuleMatchingService(mockPayeeRepository, mockTransactionRepository);
  });

  final testTransaction = Transaction(
    id: '1',
    accountId: 'acc1',
    date: DateTime.now(),
    amount: -50.0,
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

  group('RuleMatchingService', () {
    test('matches payee correctly', () async {
      when(mockPayeeRepository.getPayeeById('payee1'))
          .thenAnswer((_) async => testPayee);

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
        actions: [
          RuleAction(type: RuleActionType.setMemo, value: 'Matched'),
        ],
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
            value: '-40.0', // -50 < -40
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
              value: '-50.0')
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

    test('respects priority', () async {
        const rule1 = Rule(
            id: 'r1',
            name: 'Rule 1',
            priority: 1,
            isActive: true,
            matchLogic: RuleMatchLogic.and,
            conditions: [RuleCondition(type: RuleConditionType.amount, operator: RuleConditionOperator.equals, value: '-50.0')],
            actions: [RuleAction(type: RuleActionType.setMemo, value: 'Rule1')],
        );

        const rule2 = Rule(
            id: 'r2',
            name: 'Rule 2',
            priority: 2,
            isActive: true,
            matchLogic: RuleMatchLogic.and,
            conditions: [RuleCondition(type: RuleConditionType.amount, operator: RuleConditionOperator.equals, value: '-50.0')],
            actions: [RuleAction(type: RuleActionType.setMemo, value: 'Rule2')],
        );

        // Rule 1 runs first, sets memo to Rule1.
        // Rule 2 runs second, sets memo to Rule2.
        final result = await service.applyRules([testTransaction], [rule2, rule1]);
        expect(result.first.memo, 'Rule2');

        // Reverse priority in rule definition (lower value = higher priority)
        final rule3 = rule1.copyWith(priority: 10);
        final rule4 = rule2.copyWith(priority: 1); // This runs first

        // Rule 4 (Rule2 copy) runs first because 1 < 10. Sets memo to Rule2.
        // Rule 3 (Rule1 copy) runs second. Sets memo to Rule1.

        final result2 = await service.applyRules([testTransaction], [rule3, rule4]);
        expect(result2.first.memo, 'Rule1');
    });
  });
}
