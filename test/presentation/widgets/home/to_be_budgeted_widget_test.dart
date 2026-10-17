import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/home/to_be_budgeted_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../widget_test_helpers.dart';

const _checking = Account(
  id: 'c',
  name: 'Checking',
  type: AccountType.checking,
  balance: 120000,
);
const _savings = Account(
  id: 's',
  name: 'Savings',
  type: AccountType.savings,
  balance: 900000,
  onBudget: false,
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(WidgetTester tester, List<Account> accounts) =>
      pumpTestWidget(
        tester,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: ToBeBudgetedWidget(),
        ),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
          tbbProvider.overrideWith((ref, month) => Future.value(25000)),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        ],
      );

  group('homeBalancePages', () {
    test('To Be Budgeted only without accounts', () {
      expect(homeBalancePages(const []), [HomeBalancePage.toBeBudgeted]);
    });

    test('no budget total when every account is on budget', () {
      expect(homeBalancePages(const [_checking]), [
        HomeBalancePage.toBeBudgeted,
        HomeBalancePage.netWorth,
      ]);
    });

    test('all three with an off-budget account', () {
      expect(homeBalancePages(const [_checking, _savings]), [
        HomeBalancePage.toBeBudgeted,
        HomeBalancePage.netWorth,
        HomeBalancePage.inBudget,
      ]);
    });

    test('no sums across currencies', () {
      expect(
        homeBalancePages([_checking, _savings.copyWith(currency: 'EUR')]),
        [HomeBalancePage.toBeBudgeted],
      );
    });
  });

  testWidgets('swiping shows net worth, then the budget accounts total', (
    tester,
  ) async {
    await pump(tester, const [_checking, _savings]);
    expect(find.text('\$250.00'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(find.text('\$10,200.00'), findsOneWidget);
    expect(prefs.getString(ToBeBudgetedWidget.pagePrefsKey), 'netWorth');

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('IN BUDGET ACCOUNTS'), findsOneWidget);
    expect(find.text('\$1,200.00'), findsOneWidget);
  });

  testWidgets('tapping cycles through the pages', (tester) async {
    await pump(tester, const [_checking]);
    await tester.tap(find.byType(ToBeBudgetedWidget));
    await tester.pumpAndSettle();
    expect(find.text('\$1,200.00'), findsOneWidget);
    await tester.tap(find.byType(ToBeBudgetedWidget));
    await tester.pumpAndSettle();
    expect(find.text('\$250.00'), findsOneWidget);
  });

  testWidgets('opens on the page shown last', (tester) async {
    await prefs.setString(ToBeBudgetedWidget.pagePrefsKey, 'inBudget');
    await pump(tester, const [_checking, _savings]);
    expect(find.text('IN BUDGET ACCOUNTS'), findsOneWidget);
  });

  testWidgets('a single page has no swipe affordance', (tester) async {
    await pump(tester, const []);
    expect(find.text('\$250.00'), findsOneWidget);
    await tester.tap(find.byType(ToBeBudgetedWidget));
    await tester.pumpAndSettle();
    expect(find.text('\$250.00'), findsOneWidget);
  });
}
