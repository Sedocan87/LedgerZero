import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/services/import/rule_import_export_service.dart';

import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late ProviderContainer container;
  late String groceries;

  setUp(() async {
    t = TestDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(t.db)],
    );
    groceries = await t.categoryId('Groceries');
    await t.addAccount(id: 'acc', name: 'Checking');
  });

  tearDown(() async {
    container.dispose();
    await t.close();
  });

  Map<String, dynamic> rule(
    String id,
    List<Map<String, dynamic>> actions, {
    bool isActive = true,
  }) => {
    'id': id,
    'name': 'Rule $id',
    'description': null,
    'priority': 0,
    'isActive': isActive,
    'matchLogic': 'and',
    'conditions': [
      {'type': 'description', 'operator': 'contains', 'value': 'shop'},
    ],
    'actions': actions,
  };

  test('(I9) actions with unknown targets are dropped and reported; the '
      'imported rules never cause a foreign-key failure', () async {
    final json = jsonEncode([
      rule('ok', [
        {'type': 'setCategory', 'value': groceries},
      ]),
      rule('mixed', [
        {'type': 'setCategory', 'value': 'cat-from-other-phone'},
        {'type': 'setMemo', 'value': 'weekly shop'},
      ]),
      rule('orphan', [
        {'type': 'setPayee', 'value': 'payee-from-other-phone'},
        {'type': 'setAccount', 'value': 'acc-from-other-phone'},
      ]),
    ]);

    final result = await container
        .read(ruleImportExportServiceProvider)
        .importRulesFromJson(json);
    expect(result.imported, 3);
    expect(result.droppedActions, 3);

    final mixed = (await t.rules.getRule('mixed'))!;
    expect(mixed.actions.map((a) => a.type), [RuleActionType.setMemo]);
    expect(mixed.isActive, isTrue);
    final orphan = (await t.rules.getRule('orphan'))!;
    expect(orphan.actions, isEmpty);
    expect(orphan.isActive, isFalse);

    // What a CSV import does with the imported rules.
    final matching = container.read(ruleMatchingServiceProvider);
    final active = await matching.loadActiveRules();
    final row = Transaction(
      id: 'tx',
      accountId: 'acc',
      date: DateTime.utc(2026, 1, 5),
      amount: -1000,
      memo: 'corner shop',
    );
    final applied = await matching.apply(row, active);
    await t.transactions.upsertTransactions([applied]);
    expect(applied.categoryId, groceries);
    expect(applied.memo, 'weekly shop');
    await expectNoForeignKeyViolations(t);
  });

  test('a rule with a known id is updated, not duplicated', () async {
    final service = container.read(ruleImportExportServiceProvider);
    await service.importRulesFromJson(
      jsonEncode([
        rule('r1', [
          {'type': 'setMemo', 'value': 'one'},
        ]),
      ]),
    );
    await service.importRulesFromJson(
      jsonEncode([
        rule('r1', [
          {'type': 'setMemo', 'value': 'two'},
        ]),
      ]),
    );
    final rules = await t.rules.getRules();
    expect(rules, hasLength(1));
    expect(rules.single.actions.single.value, 'two');
  });

  test('an invalid entry is skipped, the others are imported', () async {
    final result = await container
        .read(ruleImportExportServiceProvider)
        .importRulesFromJson(
          jsonEncode([
            {'id': 'broken'},
            rule('fine', [
              {'type': 'setMemo', 'value': 'x'},
            ]),
          ]),
        );
    expect(result.imported, 1);
    expect(await t.rules.getRule('fine'), isNotNull);
  });
}
