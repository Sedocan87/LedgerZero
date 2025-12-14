import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/parsing_history_dao.dart';
import 'package:ledger_zero/domain/repositories/parsing_history_repository.dart';
import 'package:uuid/uuid.dart';

class ParsingHistoryRepositoryImpl implements ParsingHistoryRepository {
  final ParsingHistoryDao _dao;

  ParsingHistoryRepositoryImpl(this._dao);

  @override
  Future<void> addHistory(
    String input,
    String? payeeId,
    String? categoryId,
  ) async {
    await _dao.addHistory(
      ParsingHistoryCompanion.insert(
        id: const Uuid().v4(),
        input: input,
        payeeId: Value(payeeId),
        categoryId: Value(categoryId),
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(String input) async {
    final results = await _dao.getHistoryForInput(input);
    return results
        .map((e) => {'payeeId': e.payeeId, 'categoryId': e.categoryId})
        .toList();
  }
}
