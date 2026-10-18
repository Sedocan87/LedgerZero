import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/services/category_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';

import '../../../../helpers/test_database.dart';

/// Undoing a budget edit after the category was deleted shows the generic
/// error instead of throwing out of the snack bar.
void main() {
  testWidgets('undo of a budget edit for a deleted category shows an error', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    final t = TestDatabase();
    addTearDown(t.close);
    final month = DateTime.utc(2024, 5);
    final groceries = await t.categoryId('Groceries');
    final category = (await t.categories.getCategoryById(groceries))!;
    await t.budgeting.setCategoryBudgetedAmount(groceries, 10000, month);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          selectedBudgetMonthProvider.overrideWith((ref) => month),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: BudgetCategoryRow(
              viewModel: BudgetCategoryViewModel(
                category: category,
                budgeted: 10000,
                activity: 0,
                available: 10000,
                goalTarget: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Groceries'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zero Out'));
    await tester.pumpAndSettle();
    expect(find.text('Budget updated'), findsOneWidget);

    // Deleted in the meantime (budgets and transactions go with it).
    await tester.runAsync(
      () => CategoryService(
        categoryRepository: t.categories,
        maintenance: t.maintenance,
        ruleRepository: t.rules,
        unitOfWork: t.unitOfWork,
      ).deleteCategory(groceries, reassignTo: null),
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('An error occurred'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
