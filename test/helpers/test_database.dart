import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/drift_unit_of_work.dart';
import 'package:ledger_zero/data/repositories/reference_maintenance_repository_impl.dart';
import 'package:ledger_zero/domain/repositories/reference_maintenance_repository.dart';
import 'package:ledger_zero/domain/repositories/unit_of_work.dart';
import 'package:ledger_zero/data/repositories/account_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_template_repository_impl.dart';
import 'package:ledger_zero/data/repositories/category_repository_impl.dart';
import 'package:ledger_zero/data/repositories/import_profile_repository_impl.dart';
import 'package:ledger_zero/data/repositories/payee_repository_impl.dart';
import 'package:ledger_zero/data/repositories/report_note_repository_impl.dart';
import 'package:ledger_zero/data/repositories/rule_repository_impl.dart';
import 'package:ledger_zero/data/repositories/scheduled_transaction_repository_impl.dart';
import 'package:ledger_zero/data/repositories/transaction_repository_impl.dart';
import 'package:ledger_zero/domain/entities/account.dart' as domain;
import 'package:ledger_zero/domain/entities/transaction.dart' as domain;
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_template_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/import_profile_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/report_note_repository.dart';
import 'package:ledger_zero/domain/repositories/rule_repository.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

/// An in-memory [AppDatabase] (real schema, migrations, triggers and seeded
/// default categories) wired to the real repository implementations.
///
/// ```dart
/// late TestDatabase t;
/// setUp(() => t = TestDatabase());
/// tearDown(() => t.close());
/// ```
class TestDatabase {
  /// [seedName] localises the seeded default categories (see
  /// `defaultCategoryNames`); English by default.
  TestDatabase({String Function(String englishName)? seedName})
    : db = AppDatabase(NativeDatabase.memory(), seedName: seedName) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  /// Wraps an already open [db] (e.g. an encrypted file database).
  TestDatabase.wrap(this.db) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  final AppDatabase db;

  late final AccountRepository accounts = AccountRepositoryImpl(db.accountsDao);
  late final TransactionRepository transactions = TransactionRepositoryImpl(
    db.transactionsDao,
  );
  late final BudgetRepository budgets = BudgetRepositoryImpl(db.budgetsDao);
  late final CategoryRepository categories = CategoryRepositoryImpl(
    db.categoriesDao,
  );
  late final PayeeRepository payees = PayeeRepositoryImpl(db.payeesDao);
  late final ScheduledTransactionRepository scheduledTransactions =
      ScheduledTransactionRepositoryImpl(db.scheduledTransactionsDao);
  late final BudgetTemplateRepository budgetTemplates =
      BudgetTemplateRepositoryImpl(db.budgetTemplatesDao);
  late final RuleRepository rules = RuleRepositoryImpl(db.rulesDao);
  late final ReportNoteRepository reportNotes = ReportNoteRepositoryImpl(
    db.reportNotesDao,
  );
  late final ImportProfileRepository importProfiles =
      ImportProfileRepositoryImpl(db);

  late final UnitOfWork unitOfWork = DriftUnitOfWork(db);
  late final ReferenceMaintenanceRepository maintenance =
      ReferenceMaintenanceRepositoryImpl(db);

  late final BudgetingService budgeting = BudgetingService(
    transactionRepository: transactions,
    budgetRepository: budgets,
    categoryRepository: categories,
    budgetTemplateRepository: budgetTemplates,
    accountRepository: accounts,
    unitOfWork: unitOfWork,
  );

  Future<void> close() => db.close();

  var _sequence = 0;
  String _nextId(String prefix) => '$prefix-${++_sequence}';

  /// Creates an account. Amounts are minor units.
  Future<domain.Account> addAccount({
    String? id,
    String name = 'Account',
    domain.AccountType type = domain.AccountType.checking,
    String currency = 'USD',
    int startingBalance = 0,
    bool onBudget = true,
  }) async {
    final account = domain.Account(
      id: id ?? _nextId('acc'),
      name: name,
      type: type,
      currency: currency,
      startingBalance: startingBalance,
      onBudget: onBudget,
    );
    await accounts.createAccount(account);
    return account;
  }

  /// Creates a transaction. [date] defaults to today (calendar day).
  Future<domain.Transaction> addTransaction({
    required String accountId,
    required int amount,
    String? id,
    DateTime? date,
    String? categoryId,
    String? payeeId,
    String? parentTransactionId,
    String? transferAccountId,
    String? transferTransactionId,
    bool isDeleted = false,
    domain.TransactionClearStatus cleared =
        domain.TransactionClearStatus.uncleared,
  }) async {
    final transaction = domain.Transaction(
      id: id ?? _nextId('tx'),
      accountId: accountId,
      date: CalendarDate.normalize(date ?? CalendarDate.today()),
      amount: amount,
      categoryId: categoryId,
      payeeId: payeeId,
      parentTransactionId: parentTransactionId,
      transferAccountId: transferAccountId,
      transferTransactionId: transferTransactionId,
      isDeleted: isDeleted,
      cleared: cleared,
    );
    await transactions.createTransaction(transaction);
    return transaction;
  }

  /// The id of a seeded default category (by name), e.g. 'Groceries'.
  Future<String> categoryId(String name) async {
    final all = await categories.getAllCategories();
    return all.firstWhere((c) => c.name == name).id;
  }
}
