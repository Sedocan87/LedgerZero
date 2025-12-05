import 'package:ledger_zero/domain/entities/rule.dart';

abstract class RuleRepository {
  Future<List<Rule>> getRules();
  Stream<List<Rule>> watchRules();
  Future<Rule?> getRule(String id);
  Future<void> createRule(Rule rule);
  Future<void> updateRule(Rule rule);
  Future<void> deleteRule(String id);
  Future<void> reorderRules(List<Rule> rules);
}
