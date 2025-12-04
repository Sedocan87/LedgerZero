import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/parsing_rules.dart';

part 'parsing_rules_dao.g.dart';

@DriftAccessor(tables: [ParsingRules])
class ParsingRulesDao extends DatabaseAccessor<AppDatabase> with _$ParsingRulesDaoMixin {
  ParsingRulesDao(super.db);

  Future<void> addRule(ParsingRulesCompanion rule) => into(parsingRules).insert(rule);

  Future<void> updateRule(ParsingRulesCompanion rule) => update(parsingRules).replace(rule);

  Future<List<ParsingRule>> getAllRules() => select(parsingRules).get();

  Future<void> deleteRule(String id) {
    return (delete(parsingRules)..where((tbl) => tbl.id.equals(id))).go();
  }
}
