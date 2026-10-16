// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_templates_dao.dart';

// ignore_for_file: type=lint
mixin _$BudgetTemplatesDaoMixin on DatabaseAccessor<AppDatabase> {
  $BudgetTemplatesTable get budgetTemplates => attachedDatabase.budgetTemplates;
  BudgetTemplatesDaoManager get managers => BudgetTemplatesDaoManager(this);
}

class BudgetTemplatesDaoManager {
  final _$BudgetTemplatesDaoMixin _db;
  BudgetTemplatesDaoManager(this._db);
  $$BudgetTemplatesTableTableManager get budgetTemplates =>
      $$BudgetTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.budgetTemplates,
      );
}
