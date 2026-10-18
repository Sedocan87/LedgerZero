import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_calculator.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:mockito/mockito.dart';

import '../../../../mocks/repository_mocks.mocks.dart';
import '../../../../mocks/service_mocks.mocks.dart';

void main() {
  const category1 = Category(id: '1', name: 'Cat 1');

  const viewModel1 = BudgetCategoryViewModel(
    category: category1,
    budgeted: 10000,
    activity: 0,
    available: 10000,
    goalTarget: 0,
  );

  final month = DateTime.utc(2024, 5);

  Future<MockBudgetingService> pumpRow(
    WidgetTester tester,
    AppFormatter formatter,
  ) async {
    // Haptic feedback goes through the platform channel.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    final budgetingService = MockBudgetingService();
    when(
      budgetingService.setCategoryBudgetedAmount(any, any, any),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFormatterProvider.overrideWithValue(formatter),
          budgetingServiceProvider.overrideWithValue(budgetingService),
          selectedBudgetMonthProvider.overrideWith((ref) => month),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BudgetCategoryRow(viewModel: viewModel1)),
        ),
      ),
    );
    return budgetingService;
  }

  testWidgets('Tap on amount opens the calculator pre-filled', (tester) async {
    final formatter = AppFormatter(
      locale: 'en',
      currency: 'USD',
      decimalSeparator: '.',
    );
    await pumpRow(tester, formatter);

    expect(find.byType(BudgetCalculator), findsNothing);
    expect(find.text('\$100.00'), findsAny);

    await tester.tap(find.text('\$100.00').first);
    await tester.pumpAndSettle();

    expect(find.byType(BudgetCalculator), findsOneWidget);
    // Pre-filled with the input form of the budgeted amount.
    expect(find.text('100.00'), findsOneWidget);
  });

  testWidgets('Calculator input with a decimal comma saves minor units', (
    tester,
  ) async {
    final formatter = AppFormatter(
      locale: 'de',
      currency: 'EUR',
      decimalSeparator: ',',
    );
    final budgetingService = await pumpRow(tester, formatter);

    await tester.tap(find.text(formatter.formatMoney(10000)).first);
    await tester.pumpAndSettle();
    expect(find.text('100,00'), findsOneWidget);

    // The first key replaces the pre-filled value.
    for (final key in ['1', '2', ',', '5', '+', '1', ',', '2', '5']) {
      await tester.tap(
        find
            .descendant(
              of: find.byType(BudgetCalculator),
              matching: find.text(key),
            )
            .last,
      );
      await tester.pump();
    }
    expect(find.text('12,5+1,25'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    verify(budgetingService.setCategoryBudgetedAmount('1', 1375, month));
  });

  testWidgets('quick actions offer last month\'s spending, never the '
      'goal-based "Underfunded"', (tester) async {
    final formatter = AppFormatter(
      locale: 'en',
      currency: 'USD',
      decimalSeparator: '.',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    final budgetingService = MockBudgetingService();
    when(budgetingService.autoAssign(any, any, any)).thenAnswer((_) async {});
    final budgetRepository = MockBudgetRepository();
    when(
      budgetRepository.getBudgetByCategoryAndMonth(any, any),
    ).thenAnswer((_) async => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFormatterProvider.overrideWithValue(formatter),
          budgetingServiceProvider.overrideWithValue(budgetingService),
          budgetRepositoryProvider.overrideWithValue(budgetRepository),
          selectedBudgetMonthProvider.overrideWith((ref) => month),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BudgetCategoryRow(viewModel: viewModel1)),
        ),
      ),
    );

    await tester.longPress(find.text('Cat 1'));
    await tester.pumpAndSettle();
    expect(find.text('Underfunded'), findsNothing);
    await tester.tap(find.text("Budget Last Month's Spending"));
    await tester.pumpAndSettle();

    verify(
      budgetingService.autoAssign('1', month, AutoAssignRule.lastMonthSpent),
    );
  });

  testWidgets('a negative result is rejected with a message', (tester) async {
    final formatter = AppFormatter(
      locale: 'en',
      currency: 'USD',
      decimalSeparator: '.',
    );
    final budgetingService = await pumpRow(tester, formatter);

    await tester.tap(find.text('\$100.00').first);
    await tester.pumpAndSettle();
    for (final key in ['5', '-', '2', '0']) {
      await tester.tap(
        find
            .descendant(
              of: find.byType(BudgetCalculator),
              matching: find.text(key),
            )
            .last,
      );
      await tester.pump();
    }
    expect(find.text('5-20'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('A budgeted amount cannot be negative.'), findsOneWidget);
    verifyNever(budgetingService.setCategoryBudgetedAmount(any, any, any));
  });
}
