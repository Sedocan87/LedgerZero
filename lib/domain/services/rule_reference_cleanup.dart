import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';

/// Rewrites rule actions that reference a deleted (or merged) entity.
///
/// Every action of [type] whose value is [fromId] gets [toId]; when [toId]
/// is `null` the action is removed, and a rule left without actions is
/// deactivated (kept, so the user can see and fix it).
Future<void> replaceRuleActionReferences(
  RuleRepository rules, {
  required RuleActionType type,
  required String fromId,
  required String? toId,
}) async {
  for (final rule in await rules.getRules()) {
    if (!rule.actions.any((a) => a.type == type && a.value == fromId)) {
      continue;
    }
    final actions = <RuleAction>[
      for (final action in rule.actions)
        if (action.type != type || action.value != fromId)
          action
        else if (toId != null)
          RuleAction(type: type, value: toId),
    ];
    await rules.updateRule(
      rule.copyWith(
        actions: actions,
        isActive: actions.isEmpty ? false : rule.isActive,
      ),
    );
  }
}
