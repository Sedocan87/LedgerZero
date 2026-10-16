import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:uuid/uuid.dart';

/// The built-in rule templates. Their titles and descriptions are
/// localised in the presentation layer.
enum RuleTemplateKind {
  categorizeByPayee,
  autoClearSmall,
  autoApproveBill,
  keywordCategorization,
}

class RuleTemplate {
  final RuleTemplateKind kind;

  /// Creates the rule; [name] is the (localised) rule name and [keyword]
  /// the example keyword of templates that match text.
  final Rule Function({required String name, String keyword}) createRule;

  const RuleTemplate({required this.kind, required this.createRule});
}

class RuleTemplateService {
  static List<RuleTemplate> get templates => [
    RuleTemplate(
      kind: RuleTemplateKind.categorizeByPayee,
      createRule: ({required name, keyword = ''}) => Rule(
        id: const Uuid().v4(),
        name: name,
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: keyword, // User to fill
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
      kind: RuleTemplateKind.autoClearSmall,
      createRule: ({required name, keyword = ''}) => Rule(
        id: const Uuid().v4(),
        name: name,
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          const RuleCondition(
            type: RuleConditionType.amount,
            operator: RuleConditionOperator.lessThan,
            value: '500', // minor units: 5.00
          ),
        ],
        actions: [
          const RuleAction(type: RuleActionType.markCleared, value: 'true'),
        ],
      ),
    ),
    RuleTemplate(
      kind: RuleTemplateKind.autoApproveBill,
      createRule: ({required name, keyword = 'Netflix'}) => Rule(
        id: const Uuid().v4(),
        name: name,
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: keyword,
          ),
        ],
        actions: [
          const RuleAction(type: RuleActionType.markApproved, value: 'true'),
        ],
      ),
    ),
    RuleTemplate(
      kind: RuleTemplateKind.keywordCategorization,
      createRule: ({required name, keyword = ''}) => Rule(
        id: const Uuid().v4(),
        name: name,
        priority: 0,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.description,
            operator: RuleConditionOperator.contains,
            value: keyword,
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
