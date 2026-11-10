import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/daos/budgets_dao.dart';
import 'package:ledger_zero/data/database/daos/budget_templates_dao.dart';
import 'package:ledger_zero/data/database/daos/categories_dao.dart';
import 'package:ledger_zero/data/database/daos/payees_dao.dart';
import 'package:ledger_zero/data/database/daos/report_notes_dao.dart';
import 'package:ledger_zero/data/database/daos/rules_dao.dart';
import 'package:ledger_zero/data/database/daos/scheduled_transactions_dao.dart';
import 'package:ledger_zero/data/database/daos/parsing_history_dao.dart';
import 'package:ledger_zero/data/database/daos/transactions_dao.dart';
import 'package:ledger_zero/data/database/connection.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/l10n/default_category_names.dart';
import 'package:ledger_zero/presentation/providers/l10n_provider.dart';

/// The open [AppDatabase] of the session.
///
/// Rebuilt when the session opens again or [databaseGenerationProvider] is
/// bumped (after a restore); the previous connection is closed. While the
/// session is closed (factory reset, before start-up opened it), reading it
/// throws [DatabaseLockedException].
///
/// In tests, override this provider with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final open = ref.watch(sessionProvider.select((s) => s.isOpen));
  ref.watch(databaseGenerationProvider);
  if (!open) {
    throw const DatabaseLockedException();
  }
  final db = AppDatabase(
    openConnection(),
    // A new database gets its default categories in the app language.
    seedName: defaultCategoryNames(ref.read(appLocalizationsProvider)),
  );
  ref.onDispose(() => closeDatabaseOnce(db));
  return db;
});

/// Bump to reopen the database (e.g. after the file was replaced).
final databaseGenerationProvider = StateProvider<int>((ref) => 0);

final Expando<Future<void>> _closing = Expando('closing');

/// Closes [db] once; later calls return the first close.
Future<void> closeDatabaseOnce(AppDatabase db) {
  return _closing[db] ??= db.close().catchError((Object _) {});
}

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

/// Provides the [RulesDao].
final rulesDaoProvider = Provider<RulesDao>((ref) {
  return ref.watch(databaseProvider).rulesDao;
});

/// Provides the [ScheduledTransactionsDao].
final scheduledTransactionsDaoProvider = Provider<ScheduledTransactionsDao>((
  ref,
) {
  return ref.watch(databaseProvider).scheduledTransactionsDao;
});

/// Provides the [TransactionsDao].
final transactionsDaoProvider = Provider<TransactionsDao>((ref) {
  return ref.watch(databaseProvider).transactionsDao;
});

/// Provides the [ParsingHistoryDao].
final parsingHistoryDaoProvider = Provider<ParsingHistoryDao>((ref) {
  return ref.watch(databaseProvider).parsingHistoryDao;
});
