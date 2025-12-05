import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:uuid/uuid.dart';

class RuleTemplate {
  final String name;
  final String description;
  final Rule Function() createRule;

  const RuleTemplate({
    required this.name,
    required this.description,
    required this.createRule,
  });
}

class RuleTemplateService {
  static List<RuleTemplate> get templates => [
    RuleTemplate(
      name: 'Categorize by Payee Name',
      description: 'Automatically set a category when the payee name contains a specific keyword.',
      createRule: () => Rule(
        id: const Uuid().v4(),
        name: 'Categorize by Payee',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          const RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: '', // User to fill
          ),
        ],
        actions: [
          const RuleAction(
            type: RuleActionType.setCategory,
            value: '', // User to fill
          ),
        ],
      ),
    ),
    RuleTemplate(
      name: 'Small Transaction Auto-Clear',
      description: 'Automatically mark transactions under a certain amount as cleared.',
      createRule: () => Rule(
        id: const Uuid().v4(),
        name: 'Auto-Clear Small Tx',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          const RuleCondition(
            type: RuleConditionType.amount,
            operator: RuleConditionOperator.lessThan,
            value: '5.00',
          ),
        ],
        actions: [
          const RuleAction(
            type: RuleActionType.markCleared,
            value: 'true',
          ),
        ],
      ),
    ),
    RuleTemplate(
      name: 'Recurring Bill Auto-Approve',
      description: 'Automatically approve transactions for a specific payee (e.g., Netflix).',
      createRule: () => Rule(
        id: const Uuid().v4(),
        name: 'Auto-Approve Bill',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          const RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: 'Netflix',
          ),
        ],
        actions: [
          const RuleAction(
            type: RuleActionType.markApproved,
            value: 'true',
          ),
        ],
      ),
    ),
    RuleTemplate(
      name: 'Keyword Categorization',
      description: 'Set category based on a keyword in the memo/description.',
      createRule: () => Rule(
        id: const Uuid().v4(),
        name: 'Keyword Categorization',
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          const RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.contains,
            value: 'coffee',
          ),
        ],
        actions: [
          const RuleAction(
            type: RuleActionType.setCategory,
            value: '', // User to fill
          ),
        ],
      ),
    ),
  ];
}
