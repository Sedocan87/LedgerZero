import 'package:ledger_zero/domain/entities/budget_template.dart';

abstract class BudgetTemplateRepository {
  Future<List<BudgetTemplate>> getAllTemplates();
  Future<BudgetTemplate?> getTemplateById(String id);
  Future<void> createTemplate(BudgetTemplate template);
  Future<void> deleteTemplate(String id);
}
