import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/data/database/database.dart' as drift;
import 'package:ledger_zero/data/database/daos/budget_templates_dao.dart';
import 'package:ledger_zero/domain/entities/budget_template.dart';
import 'package:ledger_zero/domain/repositories/budget_template_repository.dart';

class BudgetTemplateRepositoryImpl implements BudgetTemplateRepository {
  final BudgetTemplatesDao _dao;

  BudgetTemplateRepositoryImpl(this._dao);

  @override
  Future<List<BudgetTemplate>> getAllTemplates() async {
    try {
      final rows = await _dao.getAllBudgetTemplates();
      return rows.map(_mapToEntity).toList();
    } catch (e, stack) {
      Logger.error('Failed to get budget templates', e, stack);
      throw const DatabaseException('Failed to get budget templates');
    }
  }

  @override
  Future<BudgetTemplate?> getTemplateById(String id) async {
    try {
      final row = await _dao.getBudgetTemplateById(id);
      return row != null ? _mapToEntity(row) : null;
    } catch (e, stack) {
      Logger.error('Failed to get budget template by id: $id', e, stack);
      throw const DatabaseException('Failed to get budget template');
    }
  }

  @override
  Future<void> createTemplate(BudgetTemplate template) async {
    try {
      await _dao.createBudgetTemplate(drift.BudgetTemplatesCompanion(
        id: Value(template.id),
        name: Value(template.name),
        data: Value(jsonEncode(template.data)),
        createdAt: Value(template.createdAt?.toIso8601String()),
      ));
    } catch (e, stack) {
      Logger.error('Failed to create budget template', e, stack);
      throw const DatabaseException('Failed to create budget template');
    }
  }

  @override
  Future<void> deleteTemplate(String id) async {
    try {
      await _dao.deleteBudgetTemplate(id);
    } catch (e, stack) {
      Logger.error('Failed to delete budget template: $id', e, stack);
      throw const DatabaseException('Failed to delete budget template');
    }
  }

  BudgetTemplate _mapToEntity(drift.BudgetTemplate row) {
    final Map<String, double> dataMap = {};
    try {
      final decoded = jsonDecode(row.data) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        if (value is num) {
          dataMap[key] = value.toDouble();
        }
      });
    } catch (e) {
      Logger.error('Failed to parse budget template data for id: ${row.id}', e);
    }

    return BudgetTemplate(
      id: row.id,
      name: row.name,
      data: dataMap,
      createdAt: row.createdAt != null ? DateTime.parse(row.createdAt!) : null,
    );
  }
}
