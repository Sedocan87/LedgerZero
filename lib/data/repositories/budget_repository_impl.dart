import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetsDao _budgetsDao;

  BudgetRepositoryImpl(this._budgetsDao);

  @override
  Future<List<Budget>> getAllBudgets() async {
    try {
      Logger.debug('Fetching all budgets');
      final budgets = await _budgetsDao.getAllBudgets();
      Logger.debug('Fetched ${budgets.length} budgets');
      return budgets.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch budgets', e, stackTrace);
      throw DatabaseException('Failed to fetch budgets', e);
    }
  }

  @override
  Future<Budget?> getBudgetById(String id) async {
    try {
      Logger.debug('Fetching budget with id: $id');
      final budget = await _budgetsDao.getBudgetById(id);
      Logger.debug('Budget found: ${budget != null}');
      return budget == null ? null : _mapToDomain(budget);
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch budget $id', e, stackTrace);
      throw DatabaseException('Failed to fetch budget $id', e);
    }
  }

  @override
  Future<Budget?> getBudgetByCategoryAndMonth(
      String categoryId, String month) async {
    try {
      Logger.debug('Fetching budget for category $categoryId in month $month');
      final budget =
          await _budgetsDao.getBudgetByCategoryAndMonth(categoryId, month);
      Logger.debug('Budget found: ${budget != null}');
      return budget == null ? null : _mapToDomain(budget);
    } catch (e, stackTrace) {
      Logger.error(
          'Failed to fetch budget for category $categoryId in month $month',
          e,
          stackTrace);
      throw DatabaseException(
          'Failed to fetch budget for category $categoryId', e);
    }
  }

  @override
  Future<List<Budget>> getBudgetsForMonth(String month) async {
    try {
      Logger.debug('Fetching budgets for month: $month');
      final budgets = await _budgetsDao.getBudgetsForMonth(month);
      Logger.debug('Fetched ${budgets.length} budgets for month $month');
      return budgets.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch budgets for month $month', e, stackTrace);
      throw DatabaseException('Failed to fetch budgets for month $month', e);
    }
  }

  @override
  Future<void> createBudget(Budget budget) async {
    try {
      Logger.debug('Creating budget for category ${budget.categoryId}');
      await _budgetsDao.insertBudget(_mapToCompanion(budget));
      Logger.info('Budget created successfully: ${budget.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create budget ${budget.id}', e, stackTrace);
      throw DatabaseException('Failed to create budget ${budget.id}', e);
    }
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    try {
      Logger.debug('Updating budget: ${budget.id}');
      await _budgetsDao.updateBudget(_mapToCompanion(budget));
      Logger.info('Budget updated successfully: ${budget.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update budget ${budget.id}', e, stackTrace);
      throw DatabaseException('Failed to update budget ${budget.id}', e);
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    try {
      Logger.debug('Deleting budget: $id');
      await _budgetsDao.deleteBudget(id);
      Logger.info('Budget deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete budget $id', e, stackTrace);
      throw DatabaseException('Failed to delete budget $id', e);
    }
  }

  @override
  Stream<List<Budget>> watchBudgetsForMonth(String month) {
    return _budgetsDao.watchBudgetsForMonth(month).map(
      (budgets) {
        return budgets.map(_mapToDomain).toList();
      },
    ).handleError((error, stackTrace) {
      Logger.error('Error in watchBudgetsForMonth stream', error, stackTrace);
      throw DatabaseException('Error watching budgets', error);
    });
  }

  @override
  Future<double> getTotalBudgetedByMonthRange(String endMonth) async {
    try {
      return await _budgetsDao.getTotalBudgetedByMonthRange(endMonth);
    } catch (e, stackTrace) {
      Logger.error('Failed to calculate total budgeted', e, stackTrace);
      throw DatabaseException('Failed to calculate total budgeted', e);
    }
  }

  @override
  Future<double> getTotalBudgetedByCategoryAndMonthRange(
      String categoryId, String endMonth) async {
    try {
      return await _budgetsDao.getTotalBudgetedByCategoryAndMonthRange(
          categoryId, endMonth);
    } catch (e, stackTrace) {
      Logger.error(
          'Failed to calculate total budgeted for category $categoryId',
          e,
          stackTrace);
      throw DatabaseException('Failed to calculate total budgeted', e);
    }
  }

  @override
  Future<Map<String, double>> getAllTimeBudgetedSumsUpToMonth(String endMonth) async {
    try {
      return await _budgetsDao.getBudgetedSumsByMonthRange(endMonth);
    } catch (e, stackTrace) {
      Logger.error('Failed to calculate budgeted sums', e, stackTrace);
      throw DatabaseException('Failed to calculate budgeted sums', e);
    }
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
