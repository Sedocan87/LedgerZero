// Which operators each condition field is evaluated with (fourth audit,
// ledger F5): the editor offers exactly RuleCondition.operatorsFor, so it
// must agree with what RuleMatchingService can match.
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

  final transaction = Transaction(
    id: '1',
    accountId: 'acc1',
    date: DateTime.utc(2024, 3, 1),
    amount: -5000,
    memo: 'Grocery Store Trip',
    payeeId: 'payee1',
  );

  setUp(() {
    final payees = MockPayeeRepository();
    when(payees.getPayeeById('payee1')).thenAnswer(
      (_) async => Payee(
        id: 'payee1',
        name: 'Grocery Store',
        createdAt: DateTime.utc(2024),
      ),
    );
    service = RuleMatchingService(payees, MockTransactionRepository());
  });

  /// A value with which [op] on [type] would hold for [transaction], if
  /// the field were evaluated with that operator at all.
  String valueFor(RuleConditionType type, RuleConditionOperator op) {
    if (type == RuleConditionType.amount) {
      return switch (op) {
        RuleConditionOperator.greaterThan => '-6000',
        RuleConditionOperator.lessThan => '-4000',
        _ => '-5000',
      };
    }
    final text = type == RuleConditionType.payee
        ? 'grocery store'
        : 'grocery store trip';
    return switch (op) {
      RuleConditionOperator.equals => text,
      RuleConditionOperator.contains => 'store',
      RuleConditionOperator.startsWith => 'grocery',
      RuleConditionOperator.endsWith => text.split(' ').last,
      RuleConditionOperator.regex => '^Groc',
      RuleConditionOperator.greaterThan => 'A',
      RuleConditionOperator.lessThan => 'z',
    };
  }

  for (final type in RuleConditionType.values) {
    for (final op in RuleConditionOperator.values) {
      final condition = RuleCondition(
        type: type,
        operator: op,
        value: valueFor(type, op),
      );
      test(
        '${type.name} ${op.name}: offered exactly when it can match',
        () async {
          final rule = Rule(
            id: 'r',
            name: 'r',
            priority: 0,
            isActive: true,
            matchLogic: RuleMatchLogic.and,
            conditions: [condition],
            actions: const [
              RuleAction(type: RuleActionType.setMemo, value: 'matched'),
            ],
          );
          final result = await service.apply(transaction, [rule]);
          final matched = result.memo == 'matched';
          expect(matched, condition.isEvaluable);
          expect(
            RuleCondition.operatorsFor(type).contains(op),
            condition.isEvaluable,
          );
          expect(rule.hasUnevaluableCondition, !condition.isEvaluable);
        },
      );
    }
  }

  test('every field has operators, the default first', () {
    expect(
      RuleCondition.operatorsFor(RuleConditionType.description).first,
      RuleConditionOperator.contains,
    );
    expect(
      RuleCondition.operatorsFor(RuleConditionType.payee).first,
      RuleConditionOperator.equals,
    );
    expect(
      RuleCondition.operatorsFor(RuleConditionType.amount).first,
      RuleConditionOperator.equals,
    );
  });
}
