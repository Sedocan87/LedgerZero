import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/budget_templates.dart';

part 'budget_templates_dao.g.dart';

@DriftAccessor(tables: [BudgetTemplates])
class BudgetTemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$BudgetTemplatesDaoMixin {
  BudgetTemplatesDao(super.db);

  Future<List<BudgetTemplate>> getAllBudgetTemplates() {
    return select(budgetTemplates).get();
  }

  Future<BudgetTemplate?> getBudgetTemplateById(String id) {
    return (select(
      budgetTemplates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> createBudgetTemplate(BudgetTemplatesCompanion template) {
    return into(budgetTemplates).insert(template);
  }

  Future<void> deleteBudgetTemplate(String id) {
    return (delete(budgetTemplates)..where((t) => t.id.equals(id))).go();
  }
}
