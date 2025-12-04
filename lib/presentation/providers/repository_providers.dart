import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/data/repositories/account_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_repository_impl.dart';
import 'package:ledger_zero/data/repositories/budget_template_repository_impl.dart';
import 'package:ledger_zero/data/repositories/category_repository_impl.dart';
import 'package:ledger_zero/data/repositories/import_profile_repository_impl.dart';
import 'package:ledger_zero/data/repositories/payee_repository_impl.dart';
import 'package:ledger_zero/data/repositories/parsing_history_repository_impl.dart';
import 'package:ledger_zero/data/repositories/parsing_rules_repository_impl.dart';
import 'package:ledger_zero/data/repositories/report_note_repository_impl.dart';
import 'package:ledger_zero/data/repositories/scheduled_transaction_repository_impl.dart';
import 'package:ledger_zero/data/repositories/transaction_repository_impl.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_template_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/import_profile_repository.dart';
import 'package:ledger_zero/domain/repositories/parsing_history_repository.dart';
import 'package:ledger_zero/domain/repositories/parsing_rules_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/report_note_repository.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';

/// Provides the [AccountRepository].
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(ref.watch(accountsDaoProvider));
});

/// Provides the [BudgetRepository].
final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepositoryImpl(ref.watch(budgetsDaoProvider));
});

/// Provides the [BudgetTemplateRepository].
final budgetTemplateRepositoryProvider = Provider<BudgetTemplateRepository>((ref) {
  return BudgetTemplateRepositoryImpl(ref.watch(budgetTemplatesDaoProvider));
});

/// Provides the [CategoryRepository].
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(ref.watch(categoriesDaoProvider));
});

/// Provides the [PayeeRepository].
final payeeRepositoryProvider = Provider<PayeeRepository>((ref) {
  return PayeeRepositoryImpl(ref.watch(payeesDaoProvider));
});

/// Provides the [ReportNoteRepository].
final reportNoteRepositoryProvider = Provider<ReportNoteRepository>((ref) {
  return ReportNoteRepositoryImpl(ref.watch(reportNotesDaoProvider));
});

/// Provides the [ScheduledTransactionRepository].
final scheduledTransactionRepositoryProvider = Provider<ScheduledTransactionRepository>((ref) {
  return ScheduledTransactionRepositoryImpl(ref.watch(scheduledTransactionsDaoProvider));
});

/// Provides the [TransactionRepository].
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionsDaoProvider));
});

/// Provides the [ParsingHistoryRepository].
final parsingHistoryRepositoryProvider = Provider<ParsingHistoryRepository>((ref) {
  return ParsingHistoryRepositoryImpl(ref.watch(parsingHistoryDaoProvider));
});

/// Provides the [ParsingRulesRepository].
final parsingRulesRepositoryProvider = Provider<ParsingRulesRepository>((ref) {
  return ParsingRulesRepositoryImpl(ref.watch(parsingRulesDaoProvider));
});

/// Provides the [ImportProfileRepository].
final importProfileRepositoryProvider = Provider<ImportProfileRepository>((ref) {
  return ImportProfileRepositoryImpl(ref.read(databaseProvider));
});
