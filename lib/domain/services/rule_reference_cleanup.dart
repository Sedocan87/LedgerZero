import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
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

/// Rewrites rule conditions "Payee equals [from]" (compared ignoring case,
/// as the matching does) to "Payee equals [to]", after the payee named
/// [from] was renamed or merged into the payee named [to].
///
/// Conditions are matched by name, so without this a rename or merge
/// silently stops the rule, e.g. the suggested rule "Rewe -> Groceries".
/// Other operators (contains, starts with, regex) describe a pattern the
/// user typed and are left alone. Returns how many rules changed.
Future<int> renamePayeeConditions(
  RuleRepository rules, {
  required String from,
  required String to,
}) async {
  final old = from.trim().toLowerCase();
  if (old.isEmpty || old == to.trim().toLowerCase()) {
    return 0;
  }
  bool matches(RuleCondition c) =>
      c.type == RuleConditionType.payee &&
      c.operator == RuleConditionOperator.equals &&
      c.value.trim().toLowerCase() == old;
  var changed = 0;
  for (final rule in await rules.getRules()) {
    if (!rule.conditions.any(matches)) {
      continue;
    }
    await rules.updateRule(
      rule.copyWith(
        conditions: [
          for (final c in rule.conditions)
            if (matches(c))
              RuleCondition(type: c.type, operator: c.operator, value: to)
            else
              c,
        ],
      ),
    );
    changed++;
  }
  return changed;
}
