import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/domain/services/payee_service.dart';

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
  late PayeeService service;

  setUp(() async {
    t = TestDatabase();
    service = PayeeService(
      payeeRepository: t.payees,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
    );
    await seedPayeeReferences(t);
  });

  tearDown(() => t.close());

  test('mergePayees moves every reference and deletes the source', () async {
    await service.mergePayees('source', 'target');

    await expectPayeeReferences(t, 'target');
    expect(await t.payees.getPayeeById('target'), isNotNull);
    await expectLedgerInvariant(t, DateTime.utc(2026, 5));
  });

  test('deletePayee clears every reference', () async {
    await service.deletePayee('source');

    await expectPayeeReferences(t, null);
    await expectLedgerInvariant(t, DateTime.utc(2026, 5));
  });

  test('merging into itself or from a missing payee is a no-op', () async {
    await service.mergePayees('source', 'source');
    await service.mergePayees('missing', 'target');
    expect(await t.payees.getPayeeById('source'), isNotNull);
    expect(await column(t, 'transactions', 'live', 'payee_id'), 'source');
  });

  test('(L13) deleting clears the undo stack', () async {
    final undo = UndoService()..addAction(_NoopAction());
    final withUndo = PayeeService(
      payeeRepository: t.payees,
      maintenance: t.maintenance,
      ruleRepository: t.rules,
      unitOfWork: t.unitOfWork,
      undoService: undo,
    );
    expect(undo.canUndo, isTrue);
    await withUndo.deletePayee('source');
    expect(undo.canUndo, isFalse);
    expect(undo.canRedo, isFalse);
  });

  group('rules that match the payee by name (ledger F6)', () {
    Rule rule(String id, RuleConditionOperator op, String value) => Rule(
      id: id,
      name: id,
      priority: 0,
      isActive: true,
      matchLogic: RuleMatchLogic.and,
      conditions: [
        RuleCondition(
          type: RuleConditionType.payee,
          operator: op,
          value: value,
        ),
        const RuleCondition(
          type: RuleConditionType.description,
          operator: RuleConditionOperator.equals,
          value: 'Shop Inc',
        ),
      ],
      actions: const [RuleAction(type: RuleActionType.setMemo, value: 'x')],
    );

    Future<List<String>> payeeValues(String id) async => [
      for (final c in (await t.rules.getRule(id))!.conditions)
        if (c.type == RuleConditionType.payee) c.value,
    ];

    setUp(() async {
      // "Shop Inc" is the source payee of the seed.
      await t.rules.createRule(
        rule('equals', RuleConditionOperator.equals, 'shop inc'),
      );
      await t.rules.createRule(
        rule('contains', RuleConditionOperator.contains, 'Shop Inc'),
      );
    });

    test('a rename rewrites "payee equals" conditions only', () async {
      await service.renamePayee('source', '  Shop Incorporated ');
      expect(
        (await t.payees.getPayeeById('source'))!.name,
        'Shop Incorporated',
      );
      expect(await payeeValues('equals'), ['Shop Incorporated']);
      // A pattern the user typed, and other fields, stay as they are.
      expect(await payeeValues('contains'), ['Shop Inc']);
      final description = (await t.rules.getRule('equals'))!.conditions.last;
      expect(description.value, 'Shop Inc');
    });

    test('a merge rewrites them to the target\'s name', () async {
      await service.mergePayees('source', 'target');
      expect(await payeeValues('equals'), ['Shop']);
      expect(await payeeValues('contains'), ['Shop Inc']);
    });

    test('a rename to another payee\'s name is refused and changes '
        'nothing', () async {
      await expectLater(
        service.renamePayee('source', 'SHOP'),
        throwsA(
          isA<PayeeNameTakenException>().having(
            (e) => e.existing.id,
            'existing',
            'target',
          ),
        ),
      );
      expect((await t.payees.getPayeeById('source'))!.name, 'Shop Inc');
      expect(await payeeValues('equals'), ['shop inc']);
    });

    test('changing only the case is allowed', () async {
      await service.renamePayee('source', 'SHOP INC');
      expect((await t.payees.getPayeeById('source'))!.name, 'SHOP INC');
    });

    test(
      'an old name still carried by another payee keeps its rules',
      () async {
        // A duplicate from before names were unique.
        await t.payees.createPayee(const Payee(id: 'twin', name: 'Shop Inc'));
        await service.renamePayee('source', 'Shop North');
        expect(await payeeValues('equals'), ['shop inc']);
        await service.mergePayees('twin', 'target');
        expect(await payeeValues('equals'), ['Shop']);
      },
    );
  });
}
