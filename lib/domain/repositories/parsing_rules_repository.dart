abstract class ParsingRulesRepository {
  Future<void> addRule(String keyword, String? payeeId, String? categoryId);
  Future<void> deleteRule(String id);
  Future<List<Map<String, dynamic>>> getAllRules();
}
