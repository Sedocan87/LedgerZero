import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/domain/entities/rule.dart';

class RuleConflict {
  final Rule ruleA;
  final Rule ruleB;
  final String description;

  const RuleConflict({
    required this.ruleA,
    required this.ruleB,
    required this.description,
  });
}

class RuleConflictService {
  List<RuleConflict> detectConflicts(List<Rule> rules) {
    final conflicts = <RuleConflict>[];
    if (rules.length < 2) {
      return conflicts;
    }

    for (int i = 0; i < rules.length; i++) {
      for (int j = i + 1; j < rules.length; j++) {
        final ruleA = rules[i];
        final ruleB = rules[j];

        if (_areConditionsIdentical(ruleA, ruleB) &&
            _areActionsConflicting(ruleA, ruleB)) {
          conflicts.add(
            RuleConflict(
              ruleA: ruleA,
              ruleB: ruleB,
              description:
                  'Rules have identical conditions but conflicting actions.',
            ),
          );
        }
      }
    }
    return conflicts;
  }

  bool _areConditionsIdentical(Rule ruleA, Rule ruleB) {
    if (ruleA.matchLogic != ruleB.matchLogic) {
      return false;
    }
    if (ruleA.conditions.length != ruleB.conditions.length) {
      return false;
    }

    // Naive check: does every condition in A exist in B?
    // This assumes strict equality of conditions.
    for (final condA in ruleA.conditions) {
      final hasMatch = ruleB.conditions.any(
        (condB) =>
            condB.type == condA.type &&
            condB.operator == condA.operator &&
            condB.value == condA.value,
      );
      if (!hasMatch) {
        return false;
      }
    }
    return true;
  }

  bool _areActionsConflicting(Rule ruleA, Rule ruleB) {
    // Check if both rules modify the same field to different values
    for (final actionA in ruleA.actions) {
      for (final actionB in ruleB.actions) {
        if (actionA.type == actionB.type && actionA.value != actionB.value) {
          return true;
        }
      }
    }
    return false;
  }
}

final ruleConflictServiceProvider = Provider((ref) => RuleConflictService());
