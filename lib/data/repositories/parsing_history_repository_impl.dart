import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
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
    try {
      await _dao.addHistory(
        ParsingHistoryCompanion.insert(
          id: const Uuid().v4(),
          input: input,
          payeeId: Value(payeeId),
          categoryId: Value(categoryId),
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stackTrace) {
      Logger.error('Failed to save parsing history', e, stackTrace);
      throw DatabaseException('Failed to save parsing history', e);
    }
  }

  /// Entries for exactly [input], most recent first.
  @override
  Future<List<Map<String, dynamic>>> getHistory(String input) async {
    try {
      final results = await _dao.getHistoryForInput(input);
      return results
          .map((e) => {'payeeId': e.payeeId, 'categoryId': e.categoryId})
          .toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to read parsing history', e, stackTrace);
      throw DatabaseException('Failed to read parsing history', e);
    }
  }
}
