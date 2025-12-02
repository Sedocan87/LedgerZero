import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:mockito/mockito.dart';

import '../../../../mocks/service_mocks.mocks.dart';

void main() {
  const category = Category(id: 'cat1', name: 'Test Category');
  late MockBudgetingService mockBudgetingService;

  setUp(() {
    mockBudgetingService = MockBudgetingService();
    // Stub the setCategoryBudgetedAmount method
    when(mockBudgetingService.setCategoryBudgetedAmount(any, any, any))
        .thenAnswer((_) async {});
    // Stub the autoAssign method
    when(mockBudgetingService.autoAssign(any, any, any))
        .thenAnswer((_) async {});
  });

  Widget buildTestWidget({required Widget child, required List<Override> overrides}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('BudgetCategoryRow allows inline editing of budgeted amount', (tester) async {
    const viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 100.0,
      activity: -50.0,
      available: 50.0,
    );

    final month = DateTime(2023, 10);

    await tester.pumpWidget(buildTestWidget(
      child: BudgetCategoryRow(viewModel: viewModel),
      overrides: [
        budgetingServiceProvider.overrideWithValue(mockBudgetingService),
        selectedBudgetMonthProvider.overrideWith((ref) => month),
        budgetViewModelProvider.overrideWith((ref) => Future.value([])),
        tbbProvider.overrideWith((ref) => Future.value(0.0)),
      ],
    ));

    // Tap on the budgeted amount
    await tester.tap(find.text('\$100.00'));
    await tester.pumpAndSettle();

    // Now it should show input field
    expect(find.byType(TextField), findsOneWidget);

    // Enter new value
    await tester.enterText(find.byType(TextField), '250.00');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    // Verify service call
    verify(mockBudgetingService.setCategoryBudgetedAmount(
      'cat1',
      250.0,
      month,
    )).called(1);
  });

  testWidgets('BudgetCategoryRow shows quick actions on long press', (tester) async {
    final viewModel = BudgetCategoryViewModel(
      category: category,
      budgeted: 100.0,
      activity: -50.0,
      available: 50.0,
    );

    final month = DateTime(2023, 10);

    await tester.pumpWidget(buildTestWidget(
      child: BudgetCategoryRow(viewModel: viewModel),
      overrides: [
        budgetingServiceProvider.overrideWithValue(mockBudgetingService),
        selectedBudgetMonthProvider.overrideWith((ref) => month),
        budgetViewModelProvider.overrideWith((ref) => Future.value([])),
        tbbProvider.overrideWith((ref) => Future.value(0.0)),
      ],
    ));

    // Long press on the budgeted amount
    await tester.longPress(find.text('\$100.00'));
    await tester.pumpAndSettle();

    // Verify bottom sheet appears with options
    // Since AppLocalizations might be mocked or real, checking for text or icons
    // The test environment should load real localizations if configured correctly.
    // If not, we check for icons.

    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

    // Tap "Budget Previous Month" (History icon)
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();

    // Verify service call
    verify(mockBudgetingService.autoAssign(
      'cat1',
      month,
      AutoAssignRule.lastMonthBudgeted,
    )).called(1);
  });
}
