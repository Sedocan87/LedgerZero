import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';

class WidgetCategorySummary {
  final String id;
  final String name;
  final double available;
  final double percentFunded;

  WidgetCategorySummary({
    required this.id,
    required this.name,
    required this.available,
    required this.percentFunded,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'available': available,
        'percentFunded': percentFunded,
      };
}

class WidgetTransactionSummary {
  final String id;
  final String payeeName;
  final double amount;
  final String date;
  final String? categoryName;

  WidgetTransactionSummary({
    required this.id,
    required this.payeeName,
    required this.amount,
    required this.date,
    this.categoryName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'payeeName': payeeName,
        'amount': amount,
        'date': date,
        'categoryName': categoryName,
      };
}

class WidgetService {
  static const String _iOSWidgetName = 'LedgerZeroWidget';

  final BudgetingService _budgetingService;
  final TransactionRepository _transactionRepository;
  final CategoryRepository _categoryRepository;
  final PayeeRepository _payeeRepository;

  WidgetService(
    this._budgetingService,
    this._transactionRepository,
    this._categoryRepository,
    this._payeeRepository,
  );

  Future<void> updateWidgetData() async {
    try {
      // 1. To Be Budgeted
      final currentMonth = DateTime.now();
      final tbb = await _budgetingService.calculateTBB(currentMonth);

      await HomeWidget.saveWidgetData<double>('tbb_amount', tbb);

      // 2. Categories
      // Fetch some "top" or active categories.
      // Strategy: Get top 4 categories by available amount (or maybe lowest available if underfunded?).
      // Let's use top 4 available amount for now as a simple metric, or random active ones.
      // Better: Fetch all and sort by available amount descending.

      final allCategories = await _categoryRepository.getAllCategories();
      // We need their available amounts.
      final categoryPerformance = await _budgetingService.calculateBatchCategoryPerformance(currentMonth);

      final List<WidgetCategorySummary> categoriesList = [];
      for (final category in allCategories) {
        final available = categoryPerformance[category.id]?['available'] ?? 0.0;
        final funded = await _budgetingService.calculateFundedPercentage(category, currentMonth);

        // Exclude hidden categories if any (Category entity has isHidden)
        if (category.isHidden) continue;

        categoriesList.add(WidgetCategorySummary(
          id: category.id,
          name: category.name,
          available: available,
          percentFunded: funded,
        ));
      }

      // Sort by available amount descending, take top 4
      categoriesList.sort((a, b) => b.available.compareTo(a.available));
      final topCategories = categoriesList.take(4).toList();

      final categoriesJson = jsonEncode(topCategories.map((e) => e.toJson()).toList());
      await HomeWidget.saveWidgetData<String>('categories_json', categoriesJson);

      // 3. Recent Transactions
      final transactions = await _transactionRepository.getTransactions(limit: 5);

      final widgetTransactions = <WidgetTransactionSummary>[];

      for (final t in transactions) {
        String payeeName = "Unknown Payee";
        if (t.payeeId != null) {
          final payee = await _payeeRepository.getPayeeById(t.payeeId!);
          payeeName = payee?.name ?? "Unknown Payee";
        }

        String? categoryName;
        if (t.categoryId != null) {
          final category = await _categoryRepository.getCategoryById(t.categoryId!);
          categoryName = category?.name;
        }

        widgetTransactions.add(WidgetTransactionSummary(
          id: t.id,
          payeeName: payeeName,
          amount: t.amount,
          date: DateFormat('MMM d').format(t.date),
          categoryName: categoryName,
        ));
      }

      final transactionsJson = jsonEncode(widgetTransactions.map((e) => e.toJson()).toList());
      await HomeWidget.saveWidgetData<String>('transactions_json', transactionsJson);

      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      Logger.error('Error updating widget data', e);
    }
  }
}
