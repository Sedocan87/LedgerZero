import 'dart:convert';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/services/export/export_file_service.dart';

class DataPortabilityService {
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final CategoryRepository _categoryRepository;
  final PayeeRepository _payeeRepository;
  final BudgetRepository _budgetRepository;
  final ScheduledTransactionRepository _scheduledTransactionRepository;
  final ExportFileService _files;

  DataPortabilityService(
    this._accountRepository,
    this._transactionRepository,
    this._categoryRepository,
    this._payeeRepository,
    this._budgetRepository,
    this._scheduledTransactionRepository, {
    ExportFileService? files,
  }) : _files = files ?? ExportFileService();

  /// Shares all data as JSON; [shareText] is the localised share sheet
  /// text.
  Future<void> exportAllDataToJson({String? shareText}) async {
    final accounts = await _accountRepository.getAllAccounts();
    final transactions = await _transactionRepository.getAllTransactions();
    final categories = await _categoryRepository.getAllCategories();
    final categoryGroups = await _categoryRepository.getAllCategoryGroups();
    final payees = await _payeeRepository.getAllPayees();
    final budgets = await _budgetRepository.getAllBudgets();
    final scheduledTransactions = await _scheduledTransactionRepository
        .getAllScheduledTransactions();

    final data = {
      'metadata': {
        // 2.0: every amount is an integer of minor units (hundredths),
        // dates are UTC ISO-8601 (calendar days at UTC midnight), and
        // accounts carry a computed `balance` instead of `current_balance`.
        'version': '2.0',
        'amount_unit': 'minor',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'app': 'LedgerZero',
      },
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'category_groups': categoryGroups.map((e) => e.toJson()).toList(),
      'payees': payees.map((e) => e.toJson()).toList(),
      'budgets': budgets.map((e) => e.toJson()).toList(),
      'scheduled_transactions': scheduledTransactions
          .map((e) => e.toJson())
          .toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    // Plaintext by design (the portability path); written to the temporary
    // export directory and deleted after sharing.
    final file = await _files.writeString(
      'ledger_zero_export_$dateStr.json',
      jsonString,
    );
    await _files.shareAndDelete(file, text: shareText);
  }
}
