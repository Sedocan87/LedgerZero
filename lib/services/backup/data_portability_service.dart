import 'dart:convert';
import 'dart:io';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/budget_repository.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class DataPortabilityService {
  final AccountRepository _accountRepository;
  final TransactionRepository _transactionRepository;
  final CategoryRepository _categoryRepository;
  final PayeeRepository _payeeRepository;
  final BudgetRepository _budgetRepository;
  final ScheduledTransactionRepository _scheduledTransactionRepository;

  DataPortabilityService(
    this._accountRepository,
    this._transactionRepository,
    this._categoryRepository,
    this._payeeRepository,
    this._budgetRepository,
    this._scheduledTransactionRepository,
  );

  Future<void> exportAllDataToJson() async {
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
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
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

    final dir = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'ledger_zero_export_$dateStr.json';
    final file = File('${dir.path}/$filename');

    await file.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        text: 'LedgerZero Data Export (JSON)',
        files: [XFile(file.path)],
      ),
    );
  }
}
