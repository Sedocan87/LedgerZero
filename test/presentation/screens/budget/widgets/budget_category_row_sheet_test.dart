// Sheets opened from a budget row: the calculator validates before it
// closes, a failed write is reported, and the write goes to the category
// the sheet was opened for even when the list changes underneath it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';
import 'package:ledger_zero/presentation/screens/budget/providers/budget_ui_state_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_calculator.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_list.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_group_row.dart';
import 'package:mockito/mockito.dart';

import '../../../../mocks/service_mocks.mocks.dart';

BudgetCategoryViewModel vm(
  String id, {
  int budgeted = 0,
  int activity = 0,
  int available = 0,
}) => BudgetCategoryViewModel(
  category: Category(id: id, name: 'Cat $id'),
  budgeted: budgeted,
  activity: activity,
  available: available,
  goalTarget: 0,
);

List<BudgetGroupViewModel> oneGroup(List<BudgetCategoryViewModel> categories) =>
    [
      BudgetGroupViewModel(
        group: const CategoryGroup(id: 'g', name: 'Group'),
        categories: categories,
      ),
    ];

final _groups = StateProvider<List<BudgetGroupViewModel>>((ref) => const []);

void main() {
  final month = DateTime.utc(2024, 5);
  final formatter = AppFormatter(
    locale: 'en',
    currency: 'USD',
    decimalSeparator: '.',
  );
  late MockBudgetingService budgeting;

  setUp(() {
    budgeting = MockBudgetingService();
    when(
      budgeting.setCategoryBudgetedAmount(any, any, any),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester,
    Widget body, {
    List<Override> overrides = const [],
  }) async {
    // Haptic feedback goes through the platform channel.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFormatterProvider.overrideWithValue(formatter),
          budgetingServiceProvider.overrideWithValue(budgeting),
          selectedBudgetMonthProvider.overrideWith((ref) => month),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, List<String> keys) async {
    for (final key in keys) {
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
  }

  group('calculator', () {
    for (final (name, keys) in [
      ('an unfinished expression', ['5', '0', '+']),
      ('a division by zero', ['5', '/', '0']),
    ]) {
      testWidgets('$name keeps the calculator open with a message and saves '
          'nothing', (tester) async {
        await pump(tester, BudgetCategoryRow(viewModel: vm('1')));
        await tester.tap(find.text('\$0.00').first);
        await tester.pumpAndSettle();
        await press(tester, keys);

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.byType(BudgetCalculator), findsOneWidget);
        expect(find.text('Please enter a valid amount'), findsOneWidget);
        verifyNever(budgeting.setCategoryBudgetedAmount(any, any, any));
      });
    }

    testWidgets('the message goes away with the next key, and the corrected '
        'amount is saved', (tester) async {
      await pump(tester, BudgetCategoryRow(viewModel: vm('1')));
      await tester.tap(find.text('\$0.00').first);
      await tester.pumpAndSettle();
      await press(tester, ['5', '0', '+']);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('budget.calculatorError')), findsOneWidget);

      await press(tester, ['2', '0']);
      expect(find.byKey(const Key('budget.calculatorError')), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetCalculator), findsNothing);
      verify(budgeting.setCategoryBudgetedAmount('1', 7000, month));
    });

    testWidgets('a negative result keeps the calculator open too', (
      tester,
    ) async {
      await pump(tester, BudgetCategoryRow(viewModel: vm('1')));
      await tester.tap(find.text('\$0.00').first);
      await tester.pumpAndSettle();
      await press(tester, ['5', '-', '2', '0']);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetCalculator), findsOneWidget);
      expect(
        find.text('A budgeted amount cannot be negative.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a write that fails is reported instead of thrown', (
    tester,
  ) async {
    when(
      budgeting.setCategoryBudgetedAmount(any, any, any),
    ).thenAnswer((_) async => throw StateError('category is gone'));
    await pump(tester, BudgetCategoryRow(viewModel: vm('1', budgeted: 500)));
    await tester.longPress(find.text('Cat 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zero Out'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('An error occurred'), findsOneWidget);
    expect(find.text('Budget updated'), findsNothing);
  });

  testWidgets('tapping a row opens its sheet with the full name and the '
      'activity, which the row itself no longer shows', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 392,
        child: BudgetCategoryRow(
          viewModel: vm('1', budgeted: 10000, activity: -4250, available: 5750),
        ),
      ),
    );
    // Budgeted and Available only.
    expect(find.text('-\$42.50'), findsNothing);

    await tester.tap(find.text('Cat 1'));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const Key('budget.rowActivity'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Cat 1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Activity: -\$42.50')),
      findsOneWidget,
    );
    expect(find.text('Zero Out'), findsOneWidget);
  });

  testWidgets('a group header shows the group\'s total available in the '
      'Available column', (tester) async {
    await pump(
      tester,
      const CustomScrollView(slivers: [BudgetCategoryList()]),
      overrides: [
        budgetViewModelProvider.overrideWith(
          (ref) async => oneGroup([
            vm('a', budgeted: 1000, available: 1000),
            vm('b', budgeted: 2000, available: -250),
          ]),
        ),
      ],
    );
    final header = find.byType(BudgetGroupRow);
    expect(
      find.descendant(of: header, matching: find.text('\$7.50')),
      findsOneWidget,
    );
    // Its right edge lines up with the pills' amounts.
    final total = tester.getRect(
      find.descendant(of: header, matching: find.text('\$7.50')),
    );
    final pill = tester.getRect(find.text('\$10.00').last);
    expect(total.right, closeTo(pill.right, 1));
  });

  testWidgets('comparison view: a net refund is not shown as spending', (
    tester,
  ) async {
    await pump(
      tester,
      BudgetCategoryRow(viewModel: vm('1', activity: 5000, available: 5000)),
      overrides: [
        budgetViewModeProvider.overrideWith((ref) => BudgetViewMode.comparison),
      ],
    );
    expect(find.text('\$0.00 / \$0.00'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('\$50.00 / \$0.00'), findsNothing);
  });

  group('the list changes while the calculator is open', () {
    Future<ProviderContainer> openCalculatorForB(WidgetTester tester) async {
      await pump(
        tester,
        const CustomScrollView(slivers: [BudgetCategoryList()]),
        overrides: [
          budgetViewModelProvider.overrideWith(
            (ref) async => ref.watch(_groups),
          ),
          _groups.overrideWith(
            (ref) =>
                oneGroup([vm('a', budgeted: 1000), vm('b', budgeted: 2000)]),
          ),
        ],
      );
      await tester.tap(find.text('\$20.00'));
      await tester.pumpAndSettle();
      expect(find.byType(BudgetCalculator), findsOneWidget);
      await press(tester, ['7', '5']);
      return ProviderScope.containerOf(
        tester.element(find.byType(BudgetCategoryList)),
      );
    }

    testWidgets('a category arriving above the row (sync) does not redirect '
        'the amount to its neighbour', (tester) async {
      final container = await openCalculatorForB(tester);
      container.read(_groups.notifier).state = oneGroup([
        vm('x'),
        vm('a', budgeted: 1000),
        vm('b', budgeted: 2000),
      ]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      verify(budgeting.setCategoryBudgetedAmount('b', 7500, month));
      verifyNever(budgeting.setCategoryBudgetedAmount('a', any, any));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row disappearing (category hidden by sync) does not '
        'lose the amount', (tester) async {
      final container = await openCalculatorForB(tester);
      container.read(_groups.notifier).state = oneGroup([
        vm('a', budgeted: 1000),
      ]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      verify(budgeting.setCategoryBudgetedAmount('b', 7500, month));
      expect(find.text('Budget updated'), findsOneWidget);
    });
  });
}
