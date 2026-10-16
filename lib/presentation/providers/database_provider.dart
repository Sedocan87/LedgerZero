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

/// The open, encrypted [AppDatabase] for the unlocked session.
///
/// Rebuilt when the session key changes or [databaseGenerationProvider] is
/// bumped (after a restore); the previous connection is closed. While the
/// app is locked, reading it throws [DatabaseLockedException]: there is no
/// unkeyed fallback.
///
/// In tests, override this provider with an in-memory database.
final databaseProvider = Provider<AppDatabase>((ref) {
  final key = ref.watch(sessionProvider.select((s) => s.key));
  ref.watch(databaseGenerationProvider);
  if (key == null || key.isDestroyed) {
    throw const DatabaseLockedException();
  }
  final db = AppDatabase(
    openEncryptedConnection(key.bytes),
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

enum DatabaseEncryptionStatus { encrypted, plaintext, unknown }

/// What the security screen shows: "encrypted" only when SQLCipher is linked
/// AND the file on disk does not start with the plain SQLite header (the
/// connection itself refuses to open without the key).
final databaseEncryptionStatusProvider =
    FutureProvider.autoDispose<DatabaseEncryptionStatus>((ref) async {
      final db = ref.watch(databaseProvider);
      if (!await db.hasCipherSupport) {
        return DatabaseEncryptionStatus.plaintext;
      }
      // Make sure the file exists (the connection opens lazily).
      await db.customSelect('SELECT 1').get();
      final file = await databaseFile();
      if (!await file.exists()) {
        return DatabaseEncryptionStatus.unknown;
      }
      final raf = await file.open();
      try {
        final header = await raf.read(16);
        const plainHeader = 'SQLite format 3\u0000';
        if (String.fromCharCodes(header) == plainHeader) {
          return DatabaseEncryptionStatus.plaintext;
        }
        return DatabaseEncryptionStatus.encrypted;
      } finally {
        await raf.close();
      }
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
