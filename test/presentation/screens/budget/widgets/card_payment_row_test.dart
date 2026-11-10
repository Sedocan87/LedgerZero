// The credit-card parts of the budget screen, the category editor and the
// pickers (see docs/BUDGETING_RULES.md, "Credit cards").
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/categories/add_edit_category_screen.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late String card;
  late String groceries;
  final month = DateTime.utc(2024, 5);

  setUp(() async {
    t = TestDatabase();
    groceries = await t.categoryId('Groceries');
    final checking = (await t.addAccount(name: 'Checking')).id;
    card = (await t.addAccount(name: 'Visa', type: AccountType.credit)).id;
    final service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
      ruleMatchingService: RuleMatchingService(
        t.payees,
        t.transactions,
        t.rules,
      ),
    );
    await t.addTransaction(accountId: checking, amount: 100000, date: month);
    await t.budgeting.setCategoryBudgetedAmount(groceries, 2000, month);
    // 50 on the card, 20 budgeted: 30 of credit overspending.
    await service.save(
      TransactionInput(
        accountId: card,
        date: DateTime.utc(2024, 5, 3),
        amount: -5000,
        categoryId: groceries,
      ),
    );
  });

  tearDown(() => t.close());

  Widget app(Widget home) => ProviderScope(
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
      home: Scaffold(body: home),
    ),
  );

  Future<List<BudgetGroupViewModel>> viewModels(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(t.db),
        selectedBudgetMonthProvider.overrideWith((ref) => month),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(budgetViewModelProvider, (_, _) {});
    addTearDown(sub.close);
    return (await tester.runAsync(
      () => container.read(budgetViewModelProvider.future),
    ))!;
  }

  BudgetCategoryViewModel row(List<BudgetGroupViewModel> groups, String id) =>
      groups.expand((g) => g.categories).firstWhere((c) => c.category.id == id);

  testWidgets('the Credit Card Payments group comes first with the card\'s '
      'payment row; credit overspending is in the warning colour', (
    tester,
  ) async {
    final groups = await viewModels(tester);
    expect(groups.first.group.id, CardPayments.groupId);
    final payment = row(groups, CardPayments.categoryId(card));
    expect(payment.available, 2000);
    expect(payment.activity, 2000);
    expect(payment.payment!.missing, 3000);
    final food = row(groups, groceries);
    expect(food.available, -3000);
    expect(food.isCreditOverspent, isTrue);

    await tester.pumpWidget(
      app(
        Column(
          children: [
            BudgetCategoryRow(viewModel: payment),
            BudgetCategoryRow(viewModel: food),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Still missing: \$30.00'), findsOneWidget);
    expect(
      find.byKey(Key('budget.creditOverspent.$groceries')),
      findsOneWidget,
    );
    final amount = tester.widget<Text>(find.text('-\$30.00'));
    expect(amount.style?.color, AppColors.warning);
  });

  testWidgets('cash overspending keeps the error colour', (tester) async {
    final dining = await t.categoryId('Dining Out');
    final category = (await tester.runAsync(
      () => t.categories.getCategoryById(dining),
    ))!;
    await tester.pumpWidget(
      app(
        BudgetCategoryRow(
          viewModel: BudgetCategoryViewModel(
            category: category,
            budgeted: 0,
            activity: -1000,
            available: -1000,
            goalTarget: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(Key('budget.creditOverspent.$dining')), findsNothing);
    expect(
      tester.widget<Text>(find.text('-\$10.00').last).style?.color,
      AppColors.expense,
    );
  });

  testWidgets('the payment row offers "Cover the card balance" instead of '
      'the spending-based fills', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    final payment = row(
      await viewModels(tester),
      CardPayments.categoryId(card),
    );
    await tester.pumpWidget(app(BudgetCategoryRow(viewModel: payment)));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Visa'));
    await tester.pumpAndSettle();
    expect(find.text("Budget Last Month's Spending"), findsNothing);
    expect(find.text('Budget Previous Month'), findsOneWidget);
    await tester.tap(find.byKey(const Key('budget.coverCardBalance')));
    await tester.pumpAndSettle();
    expect(find.text('Budget updated'), findsOneWidget);

    final status = await tester.runAsync(
      () => t.budgeting.calculateCardPaymentStatus(card, month),
    );
    expect(status!.missing, 0);
    expect(status.available, 5000);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the editor of a payment category: name follows the card, no '
      'group change, no hide switch', (tester) async {
    await tester.pumpWidget(
      app(AddEditCategoryScreen(categoryId: CardPayments.categoryId(card))),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category.paymentLocked')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).readOnly,
      isTrue,
    );
    expect(find.byType(SwitchListTile), findsNothing);
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.onChanged, isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  test(
    'the transaction category pickers leave payment categories out',
    () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(t.db)],
      );
      addTearDown(container.dispose);
      final subs = [
        container.listen(categoryHierarchyProvider, (_, _) {}),
        container.listen(accountsProvider, (_, _) {}),
      ];
      addTearDown(() {
        for (final s in subs) {
          s.close();
        }
      });
      await container.read(accountsProvider.future);
      await container.read(categoriesProvider.future);
      await container.read(categoryGroupsProvider.future);
      final hierarchy = container.read(categoryHierarchyProvider).value!;
      expect(
        hierarchy.keys.map((g) => g.id),
        isNot(contains(CardPayments.groupId)),
      );
      expect(
        hierarchy.values.expand((c) => c).map((c) => c.id),
        isNot(contains(CardPayments.categoryId(card))),
      );
      expect(
        hierarchy.values.expand((c) => c).map((c) => c.id),
        contains(groceries),
      );
    },
  );
}
