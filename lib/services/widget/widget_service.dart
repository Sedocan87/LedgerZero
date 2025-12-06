import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _kPinnedCategoriesKey = 'widget_pinned_categories';

  final BudgetingService _budgetingService;
  final TransactionRepository _transactionRepository;
  final CategoryRepository _categoryRepository;
  final PayeeRepository _payeeRepository;
  final SharedPreferences _prefs;

  WidgetService(
    this._budgetingService,
    this._transactionRepository,
    this._categoryRepository,
    this._payeeRepository,
    this._prefs,
  );

  Future<void> updateWidgetData() async {
    final stopwatch = Stopwatch()..start();
    try {
      // 1. To Be Budgeted
      final currentMonth = DateTime.now();
      final tbb = await _budgetingService.calculateTBB(currentMonth);

      await HomeWidget.saveWidgetData<double>('tbb_amount', tbb);

      // 2. Categories
      // Fetch some "top" or active categories.
      final allCategories = await _categoryRepository.getAllCategories();
      // We need their available amounts.
      final categoryPerformance = await _budgetingService.calculateBatchCategoryPerformance(currentMonth);

      final pinnedCategoryIds = _prefs.getStringList(_kPinnedCategoriesKey) ?? [];

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

      List<WidgetCategorySummary> topCategories;

      if (pinnedCategoryIds.isNotEmpty) {
        // Use pinned categories
        topCategories = categoriesList
            .where((c) => pinnedCategoryIds.contains(c.id))
            .toList();

        // Sort them to match the pinned order
        topCategories.sort((a, b) {
           final indexA = pinnedCategoryIds.indexOf(a.id);
           final indexB = pinnedCategoryIds.indexOf(b.id);
           return indexA.compareTo(indexB);
        });

        // Ensure we don't exceed 4 even if prefs somehow has more
        if (topCategories.length > 4) {
          topCategories = topCategories.take(4).toList();
        }

      } else {
        // Sort by available amount descending, take top 4
        categoriesList.sort((a, b) => b.available.compareTo(a.available));
        topCategories = categoriesList.take(4).toList();
      }

      final categoriesJson = jsonEncode(topCategories.map((e) => e.toJson()).toList());
      await HomeWidget.saveWidgetData<String>('categories_json', categoriesJson);

      // 3. Recent Transactions
      // OPTIMIZED: Replaced N+1 loop with bulk fetching and caching
      final transactions = await _transactionRepository.getTransactions(limit: 5);

      // Collect IDs to fetch
      final payeeIds = transactions.map((t) => t.payeeId).whereType<String>().toSet();
      final categoryIds = transactions.map((t) => t.categoryId).whereType<String>().toSet();

      // Batch fetch Payees (if we don't have a getByIds method, we can fallback to fetching all payees if the list is small,
      // but ideally we should iterate the list we already have or add a batch fetch.
      // For now, let's assume fetching all Payees might be too heavy if there are thousands.
      // However, we only need 5 transactions worth. A loop of 5 is negligible, but 'getById' might be a DB query each time.
      // Let's optimize by fetching all relevant entities locally if we can, or just caching them.

      // Since repositories usually don't support `getByIds` out of the box in this codebase (based on previous exploration),
      // we can try to fetch them individually but concurrently.

      // Better yet, let's just fetch all categories once since we usually need them for the budget part anyway (we already did `getAllCategories` above).
      // So we can reuse `allCategories`.
      final categoryMap = {for (var c in allCategories) c.id: c};

      // For Payees, if we don't have a batch fetch, concurrent requests are better than sequential awaiting.
      // Or we can fetch all payees if the list isn't huge. But let's stick to concurrent fetch for just these 5.
      final uniquePayeeIds = payeeIds.toList();
      final List<Payee?> payees = await Future.wait(
        uniquePayeeIds.map((id) => _payeeRepository.getPayeeById(id))
      );
      final payeeMap = {
        for (var i = 0; i < uniquePayeeIds.length; i++)
          uniquePayeeIds[i]: payees[i]
      };


      final widgetTransactions = <WidgetTransactionSummary>[];

      for (final t in transactions) {
        String payeeName = "Unknown Payee";
        if (t.payeeId != null) {
          final payee = payeeMap[t.payeeId!];
          payeeName = payee?.name ?? "Unknown Payee";
        }

        String? categoryName;
        if (t.categoryId != null) {
          final category = categoryMap[t.categoryId!];
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

      stopwatch.stop();
      Logger.debug('Widget update completed in ${stopwatch.elapsedMilliseconds}ms');

    } catch (e) {
      Logger.error('Error updating widget data', e);
    }
  }
}
