abstract class ParsingHistoryRepository {
  Future<void> addHistory(String input, String? payeeId, String? categoryId);
  Future<List<Map<String, dynamic>>> getHistory(String input); // Return simple map or entity
}
