import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/parsing_rules_dao.dart';
import 'package:ledger_zero/domain/repositories/parsing_rules_repository.dart';
import 'package:uuid/uuid.dart';

class ParsingRulesRepositoryImpl implements ParsingRulesRepository {
  final ParsingRulesDao _dao;

  ParsingRulesRepositoryImpl(this._dao);

  @override
  Future<void> addRule(String keyword, String? payeeId, String? categoryId) async {
    await _dao.addRule(ParsingRulesCompanion.insert(
      id: const Uuid().v4(),
      keyword: keyword,
      payeeId: Value(payeeId),
      categoryId: Value(categoryId),
      createdAt: DateTime.now().toIso8601String(),
    ));
  }

  @override
  Future<void> deleteRule(String id) async {
    await _dao.deleteRule(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllRules() async {
    final rules = await _dao.getAllRules();
    return rules.map((e) => {
      'id': e.id,
      'keyword': e.keyword,
      'payeeId': e.payeeId,
      'categoryId': e.categoryId,
    }).toList();
  }
}
