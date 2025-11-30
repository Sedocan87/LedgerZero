import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetsDao _budgetsDao;

  BudgetRepositoryImpl(this._budgetsDao);

  @override
  Future<List<Budget>> getAllBudgets() async {
    final budgets = await _budgetsDao.getAllBudgets();
    return budgets.map(_mapToDomain).toList();
  }

  @override
  Future<Budget?> getBudgetById(String id) async {
    final budget = await _budgetsDao.getBudgetById(id);
    return budget == null ? null : _mapToDomain(budget);
  }

  @override
  Future<Budget?> getBudgetByCategoryAndMonth(
      String categoryId, String month) async {
    final budget =
        await _budgetsDao.getBudgetByCategoryAndMonth(categoryId, month);
    return budget == null ? null : _mapToDomain(budget);
  }

  @override
  Future<List<Budget>> getBudgetsForMonth(String month) async {
    final budgets = await _budgetsDao.getBudgetsForMonth(month);
    return budgets.map(_mapToDomain).toList();
  }

  @override
  Future<void> createBudget(Budget budget) async {
    await _budgetsDao.insertBudget(_mapToCompanion(budget));
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    await _budgetsDao.updateBudget(_mapToCompanion(budget));
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _budgetsDao.deleteBudget(id);
  }

  @override
  Stream<List<Budget>> watchBudgetsForMonth(String month) {
    return _budgetsDao.watchBudgetsForMonth(month).map(
          (budgets) => budgets.map(_mapToDomain).toList(),
        );
  }

  Budget _mapToDomain(db.Budget b) {
    return Budget(
      id: b.id,
      categoryId: b.categoryId,
      month: b.month,
      budgeted: b.budgeted,
      activity: b.activity,
      available: b.available,
      createdAt: b.createdAt,
      updatedAt: b.updatedAt,
    );
  }

  db.BudgetsCompanion _mapToCompanion(Budget b) {
    if (b.categoryId == null) {
      throw ArgumentError('Budget categoryId cannot be null for persistence');
    }
    return db.BudgetsCompanion(
      id: Value(b.id),
      categoryId: Value(b.categoryId!),
      month: Value(b.month),
      budgeted: Value(b.budgeted),
      activity: Value(b.activity),
      available: Value(b.available),
      createdAt: Value(b.createdAt),
      updatedAt: Value(b.updatedAt),
    );
  }
}
