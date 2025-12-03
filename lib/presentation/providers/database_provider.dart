import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:ledger_zero/data/database/daos/budget_templates_dao.dart';
import 'package:ledger_zero/data/database/daos/categories_dao.dart';
import 'package:ledger_zero/data/database/daos/payees_dao.dart';
import 'package:ledger_zero/data/database/daos/report_notes_dao.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/sync_log_dao.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/database.dart';

/// Provides the singleton instance of [AppDatabase].
///
/// In tests, you can override this provider to return an in-memory database
/// or a mocked database.
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

/// Provides the [AccountsDao].
final accountsDaoProvider = Provider<AccountsDao>((ref) {
  return ref.watch(databaseProvider).accountsDao;
});

/// Provides the [BudgetsDao].
final budgetsDaoProvider = Provider<BudgetsDao>((ref) {
  return ref.watch(databaseProvider).budgetsDao;
});

/// Provides the [BudgetTemplatesDao].
final budgetTemplatesDaoProvider = Provider<BudgetTemplatesDao>((ref) {
  return ref.watch(databaseProvider).budgetTemplatesDao;
});

/// Provides the [CategoriesDao].
final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  return ref.watch(databaseProvider).categoriesDao;
});

/// Provides the [PayeesDao].
final payeesDaoProvider = Provider<PayeesDao>((ref) {
  return ref.watch(databaseProvider).payeesDao;
});

/// Provides the [ReportNotesDao].
final reportNotesDaoProvider = Provider<ReportNotesDao>((ref) {
  return ref.watch(databaseProvider).reportNotesDao;
});

/// Provides the [ScheduledTransactionsDao].
final scheduledTransactionsDaoProvider =
    Provider<ScheduledTransactionsDao>((ref) {
  return ref.watch(databaseProvider).scheduledTransactionsDao;
});

/// Provides the [SyncLogDao].
final syncLogDaoProvider = Provider<SyncLogDao>((ref) {
  return ref.watch(databaseProvider).syncLogDao;
});

/// Provides the [TransactionsDao].
final transactionsDaoProvider = Provider<TransactionsDao>((ref) {
  return ref.watch(databaseProvider).transactionsDao;
});
