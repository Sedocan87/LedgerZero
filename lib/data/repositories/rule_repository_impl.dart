import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/rules_dao.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/rule.dart' as domain;
import 'package:ledger_zero/domain/repositories/rule_repository.dart';

class RuleRepositoryImpl implements RuleRepository {
  final RulesDao _rulesDao;

  RuleRepositoryImpl(this._rulesDao);

  @override
  Future<List<domain.Rule>> getRules() async {
    try {
      final rules = await _rulesDao.getAllRules();
      return rules.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get rules', e, stackTrace);
      throw DatabaseException('Failed to get rules', e);
    }
  }

  @override
  Stream<List<domain.Rule>> watchRules() {
    return _rulesDao.watchAllRules().map(
      (list) => list.map(_mapToDomain).toList(),
    );
  }

  @override
  Future<domain.Rule?> getRule(String id) async {
    try {
      final rule = await _rulesDao.getRuleById(id);
      return rule != null ? _mapToDomain(rule) : null;
    } catch (e, stackTrace) {
      Logger.error('Failed to get rule', e, stackTrace);
      throw DatabaseException('Failed to get rule', e);
    }
  }

  @override
  Future<void> createRule(domain.Rule rule) async {
    try {
      await _rulesDao.createRule(_mapToCompanion(rule));
    } catch (e, stackTrace) {
      Logger.error('Failed to create rule', e, stackTrace);
      throw DatabaseException('Failed to create rule', e);
    }
  }

  @override
  Future<void> updateRule(domain.Rule rule) async {
    try {
      await _rulesDao.updateRule(_mapToCompanion(rule));
    } catch (e, stackTrace) {
      Logger.error('Failed to update rule', e, stackTrace);
      throw DatabaseException('Failed to update rule', e);
    }
  }

  @override
  Future<void> deleteRule(String id) async {
    try {
      await _rulesDao.deleteRule(id);
    } catch (e, stackTrace) {
      Logger.error('Failed to delete rule', e, stackTrace);
      throw DatabaseException('Failed to delete rule', e);
    }
  }

  @override
  Future<void> reorderRules(List<domain.Rule> rules) async {
    try {
      // We need to map domain rules back to database rows, but reorderRules in DAO expects Rows.
      // Ideally we pass just IDs or similar, but let's see.
      // The DAO method reorderRules takes List<Rule> which is the generated Row class.
      // We need to convert domain.Rule to generated Rule row.

      final dbRules = rules.map(_mapToRow).toList();
      await _rulesDao.reorderRules(dbRules);
    } catch (e, stackTrace) {
      Logger.error('Failed to reorder rules', e, stackTrace);
      throw DatabaseException('Failed to reorder rules', e);
    }
  }

  // Mappers

  domain.Rule _mapToDomain(Rule rule) {
    return domain.Rule(
      id: rule.id,
      name: rule.name,
      description: rule.description,
      priority: rule.priority,
      isActive: rule.isActive,
      matchLogic: rule.matchLogic,
      conditions: rule.conditions,
      actions: rule.actions,
    );
  }

  RulesCompanion _mapToCompanion(domain.Rule rule) {
    return RulesCompanion(
      id: Value(rule.id),
      name: Value(rule.name),
      description: Value(rule.description),
      priority: Value(rule.priority),
      isActive: Value(rule.isActive),
      matchLogic: Value(rule.matchLogic),
      conditions: Value(rule.conditions),
      actions: Value(rule.actions),
      createdAt: Value(
        DateTime.now().toUtc().toIso8601String(),
      ), // Should preserve if exists? usually handled by service/usecase
      updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
    );
  }

  Rule _mapToRow(domain.Rule rule) {
    return Rule(
      id: rule.id,
      name: rule.name,
      description: rule.description,
      priority: rule.priority,
      isActive: rule.isActive,
      matchLogic: rule.matchLogic,
      conditions: rule.conditions,
      actions: rule.actions,
      createdAt: DateTime.now().toUtc().toIso8601String(), // placeholder
      updatedAt: DateTime.now().toUtc().toIso8601String(), // placeholder
    );
  }
}
