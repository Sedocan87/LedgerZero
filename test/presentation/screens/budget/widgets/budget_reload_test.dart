import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/category_group.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_list.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/to_be_budgeted_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// After a ledger write the budget providers recompute. The list, the
/// banner and the home cards keep showing what they had instead of a
/// spinner (and the banner never drops to zero in between).
void main() {
  const groups = [
    BudgetGroupViewModel(
      group: CategoryGroup(id: 'g', name: 'Bills'),
      categories: [
        BudgetCategoryViewModel(
          category: Category(id: 'c', name: 'Rent', categoryGroupId: 'g'),
          budgeted: 90000,
          activity: 0,
          available: 90000,
          goalTarget: 0,
        ),
      ],
    ),
  ];
  const noIncome = MonthIncome(
    received: 0,
    expected: 0,
    nextExpectedDate: null,
    hasRecurringIncome: false,
  );

  /// Bumped to make the providers under test recompute, like a ledger
  /// write does; the recomputation then waits for [gate].
  final reloadTrigger = StateProvider<int>((ref) => 0);
  late Completer<void> gate;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    // Created inside the test body: a completer from setUp completes
    // outside the test's fake async zone and its awaiters never run.
    gate = Completer<void>()..complete();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
          budgetViewModelProvider.overrideWith((ref) async {
            ref.watch(reloadTrigger);
            await gate.future;
            return groups;
          }),
          tbbProvider.overrideWith((ref, month) async {
            ref.watch(reloadTrigger);
            await gate.future;
            return 25000;
          }),
          monthlyStatsProvider.overrideWith((ref, month) async {
            ref.watch(reloadTrigger);
            await gate.future;
            return {'income': 300000, 'spending': -12000};
          }),
          monthIncomeProvider.overrideWith((ref, month) async => noIncome),
          accountsProvider.overrideWith(
            (ref) => Stream.value(const [
              Account(id: 'a', name: 'Checking', type: AccountType.checking),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Makes the providers recompute and holds the result back.
  Future<void> startReload(WidgetTester tester) async {
    gate = Completer<void>();
    final scope = tester.element(find.byType(Scaffold));
    ProviderScope.containerOf(scope).read(reloadTrigger.notifier).state++;
    await tester.pump();
    await tester.pump();
  }

  Future<void> finishReload(WidgetTester tester) async {
    gate.complete();
    await tester.pumpAndSettle();
  }

  testWidgets('the category list keeps its rows while recomputing', (
    tester,
  ) async {
    await pump(tester, const CustomScrollView(slivers: [BudgetCategoryList()]));
    expect(find.text('Rent'), findsOneWidget);

    await startReload(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Rent'), findsOneWidget);

    await finishReload(tester);
    expect(find.text('Rent'), findsOneWidget);
  });

  testWidgets('the To Be Budgeted banner keeps its amount', (tester) async {
    await pump(tester, const ToBeBudgetedBanner());
    expect(find.text(r'$250.00'), findsOneWidget);

    await startReload(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(r'$0.00'), findsNothing);
    expect(find.text(r'$250.00'), findsOneWidget);
    await finishReload(tester);
  });

  testWidgets('the home banner and stats keep their numbers', (tester) async {
    await pump(
      tester,
      const Column(children: [ToBeBudgetedWidget(), DashboardStatsWidget()]),
    );
    expect(find.text(r'$250.00'), findsOneWidget);
    expect(find.text(r'$3,000.00'), findsOneWidget);

    await startReload(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(r'$250.00'), findsOneWidget);
    expect(find.text(r'$3,000.00'), findsOneWidget);
    await finishReload(tester);
  });
}
