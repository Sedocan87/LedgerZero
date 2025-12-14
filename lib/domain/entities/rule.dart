import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';

enum RuleMatchLogic { and, or }

class Rule {
  final String id;
  final String name;
  final String? description;
  final int priority;
  final bool isActive;
  final RuleMatchLogic matchLogic;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;

  const Rule({
    required this.id,
    required this.name,
    this.description,
    required this.priority,
    required this.isActive,
    required this.matchLogic,
    required this.conditions,
    required this.actions,
  });

  Rule copyWith({
    String? id,
    String? name,
    String? description,
    int? priority,
    bool? isActive,
    RuleMatchLogic? matchLogic,
    List<RuleCondition>? conditions,
    List<RuleAction>? actions,
  }) {
    return Rule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      matchLogic: matchLogic ?? this.matchLogic,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
    );
  }
}
