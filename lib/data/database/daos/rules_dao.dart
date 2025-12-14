import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/rules.dart';

part 'rules_dao.g.dart';

@DriftAccessor(tables: [Rules])
class RulesDao extends DatabaseAccessor<AppDatabase> with _$RulesDaoMixin {
  RulesDao(super.db);

  Future<List<Rule>> getAllRules() => select(rules).get();

  Stream<List<Rule>> watchAllRules() {
    return (select(
      rules,
    )..orderBy([(t) => OrderingTerm(expression: t.priority)])).watch();
  }

  Future<Rule?> getRuleById(String id) {
    return (select(rules)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> createRule(RulesCompanion rule) {
    return into(rules).insert(rule);
  }

  Future<bool> updateRule(RulesCompanion rule) {
    return update(rules).replace(rule);
  }

  Future<int> deleteRule(String id) {
    return (delete(rules)..where((t) => t.id.equals(id))).go();
  }

  // Helper to reorder rules (batch update priority)
  Future<void> reorderRules(List<Rule> sortedRules) async {
    await batch((batch) {
      for (int i = 0; i < sortedRules.length; i++) {
        final rule = sortedRules[i];
        batch.update(
          rules,
          RulesCompanion(priority: Value(i)),
          where: (t) => t.id.equals(rule.id),
        );
      }
    });
  }
}
