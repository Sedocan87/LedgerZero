// The budget row with real font metrics.
//
// Widget tests normally lay text out with the square test font, which says
// nothing about whether "12.345,67 €" fits a column on a phone. This test
// loads Inter (the app's font, bundled under assets/fonts/Inter) and lays
// the one-line rows out at common phone widths: 360 dp, 392 dp (the
// owner's POCO F3) and 412 dp.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/budget_screen.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/salary_prompt.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/real_fonts.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpAll(loadInter);

  final de = AppFormatter(locale: 'de', currency: 'EUR', decimalSeparator: ',');

  /// The seeded German category names (app_de.arb, `seedCat…`).
  const germanNames = [
    'Miete/Kredit',
    'Strom',
    'Internet & Telefon',
    'Lebensmittel',
    'Mobilität',
    'Gesundheit',
    'Auto-Werkstatt',
    'Reparaturen Wohnung',
    'Versicherungen',
    'Abos & Software',
    'Studienkredit',
    'Kreditkarte',
    'Sport & Fitness',
    'Essen gehen',
    'Taschengeld',
    'Altersvorsorge',
  ];

  Future<void> pumpRows(
    WidgetTester tester, {
    required double width,
    required List<BudgetCategoryViewModel> rows,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appFormatterProvider.overrideWithValue(de)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            // As in BudgetCategoryList: the rows span the page, each with
            // its own 16 dp padding.
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (final vm in rows) BudgetCategoryRow(viewModel: vm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool hasDigit(String text) => text.contains(RegExp(r'\d'));

  /// The texts on screen that were cut off (ellipsis or dropped lines).
  List<String> cutOff(WidgetTester tester) => [
    for (final p in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    ))
      if (p.didExceedMaxLines) p.text.toPlainText(),
  ];

  /// The smallest factor by which an amount on screen was shrunk to fit
  /// its column (1.0: none was).
  double smallestAmountScale(WidgetTester tester) {
    var smallest = 1.0;
    for (final p in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    )) {
      if (hasDigit(p.text.toPlainText())) {
        final scale = p.getTransformTo(null).getMaxScaleOnAxis();
        if (scale < smallest) {
          smallest = scale;
        }
      }
    }
    return smallest;
  }

  double rowHeight(WidgetTester tester, Finder row) =>
      tester.renderObject<RenderBox>(row).size.height;

  BudgetCategoryViewModel row(
    String name, {
    required int budgeted,
    required int activity,
    required int available,
  }) => BudgetCategoryViewModel(
    category: Category(id: name, name: name),
    budgeted: budgeted,
    activity: activity,
    available: available,
    goalTarget: 0,
  );

  test('the test really measures with Inter, not the square test font', () {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'iiii',
        style: TextStyle(fontFamily: AppTextStyles.fontFamily, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Four test-font squares would be 56 wide.
    expect(painter.width, lessThan(20));
    painter.dispose();
  });

  for (final width in [360.0, 392.0, 412.0]) {
    testWidgets('at $width dp four- and five-digit amounts are shown in full '
        'on one line with the name', (tester) async {
      await pumpRows(
        tester,
        width: width,
        rows: [
          // 1.234,56 € budgeted, 246,91 € left.
          row(
            'Miete/Kredit',
            budgeted: 123456,
            activity: -98765,
            available: 24691,
          ),
          // 12.345,67 € budgeted and available.
          row(
            'Altersvorsorge',
            budgeted: 1234567,
            activity: -1234567,
            available: 1234567,
          ),
          row('Urlaub', budgeted: 25000, activity: 0, available: -1234567),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(cutOff(tester).where(hasDigit), isEmpty);
      // At full size, not shrunk to fit.
      expect(smallestAmountScale(tester), closeTo(1.0, 0.001));

      // One line, 56-64 dp: name, budgeted and available side by side.
      final rows = find.byType(BudgetCategoryRow);
      for (var i = 0; i < 3; i++) {
        expect(rowHeight(tester, rows.at(i)), inInclusiveRange(56, 64));
      }
      final name = tester.getCenter(find.text('Altersvorsorge'));
      final budgeted = tester.getCenter(
        find.text(de.formatMoney(1234567)).first,
      );
      final available = tester.getCenter(
        find.text(de.formatMoney(1234567)).last,
      );
      expect((budgeted.dy - name.dy).abs(), lessThan(4));
      expect((available.dy - name.dy).abs(), lessThan(4));
      expect(budgeted.dx, lessThan(available.dx));
      // Activity is not a column on a phone.
      expect(find.text(de.formatMoney(-98765)), findsNothing);
    });

    testWidgets('at $width dp long German names stay on one line and never '
        'push the amounts out', (tester) async {
      await pumpRows(
        tester,
        width: width,
        rows: [
          for (final name in germanNames)
            row(name, budgeted: 1234567, activity: -98765, available: 24691),
        ],
      );
      expect(tester.takeException(), isNull);
      // A long name may end in an ellipsis; an amount never does.
      final cut = cutOff(tester);
      expect(cut.where(hasDigit), isEmpty);
      expect(cut, everyElement(isIn(germanNames)));
      expect(smallestAmountScale(tester), closeTo(1.0, 0.001));
      for (final name in germanNames) {
        // The full name is still the text (screen readers, the row sheet).
        expect(find.text(name), findsOneWidget);
        final rowFinder = find.ancestor(
          of: find.text(name),
          matching: find.byType(BudgetCategoryRow),
        );
        expect(rowHeight(tester, rowFinder), inInclusiveRange(56, 64));
      }
      // The common ones fit from 392 dp on.
      if (width >= 392) {
        expect(cut, isNot(contains('Versicherungen')));
        expect(cut, isNot(contains('Lebensmittel')));
      }
    });
  }

  testWidgets('a credit card payment row keeps "Still missing" under the '
      'name and fits the row', (tester) async {
    await pumpRows(
      tester,
      width: 360,
      rows: [
        const BudgetCategoryViewModel(
          category: Category(id: 'visa', name: 'Visa Kreditkarte'),
          budgeted: 2000,
          activity: 2000,
          available: 2000,
          goalTarget: 0,
          payment: CardPaymentStatus(available: 2000, balance: -1234567),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Noch offen: ${de.formatMoney(1232567)}'), findsOneWidget);
    expect(cutOff(tester).where(hasDigit), isEmpty);
    expect(
      rowHeight(tester, find.byType(BudgetCategoryRow)),
      inInclusiveRange(56, 64),
    );
  });

  testWidgets('at 360 dp and text scale 1.3 the amounts are still readable '
      'in full', (tester) async {
    await pumpRows(
      tester,
      width: 360,
      textScale: 1.3,
      rows: [
        row(
          'Lebensmittel',
          budgeted: 123456,
          activity: -98765,
          available: 24691,
        ),
        row(
          'Versicherungen',
          budgeted: 1234567,
          activity: -1234567,
          available: 0,
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(cutOff(tester).where(hasDigit), isEmpty);
    // Never below the size they have at the normal text scale.
    expect(smallestAmountScale(tester) * 1.3, greaterThanOrEqualTo(1.0));
    // Too narrow for the name beside the amounts: the name gets its own
    // line, in full.
    expect(cutOff(tester), isEmpty);
  });

  testWidgets('on a 392 dp phone at least seven categories are visible '
      'under To Be Budgeted', (tester) async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_budget_screen_intro': true,
      'budget_tutorial_dismissed': true,
      SalaryPrompt.handledKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final t = TestDatabase();
    addTearDown(t.close);
    await t.addAccount(id: 'a', startingBalance: 250000);

    // POCO F3: 1080 x 2400 px at 2.75 (392 x 873 dp), a 28 dp status bar
    // and a 16 dp gesture bar; the tab shell's navigation bar is 68 dp.
    const dpr = 2.75;
    tester.view.physicalSize = const Size(392 * dpr, 872 * dpr);
    tester.view.devicePixelRatio = dpr;
    tester.view.padding = const FakeViewPadding(
      top: 28 * dpr,
      bottom: 16 * dpr,
    );
    addTearDown(tester.view.reset);
    const navigationBar = 68.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          selectedBudgetMonthProvider.overrideWith(
            (ref) => DateTime.utc(2024, 5),
          ),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'EUR', decimalSeparator: '.'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: BudgetScreen(),
            bottomNavigationBar: SafeArea(
              top: false,
              child: SizedBox(height: navigationBar),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    const visibleBottom = 872 - 16 - navigationBar;
    final tbbBottom = tester.getRect(find.byType(ToBeBudgetedBanner)).bottom;
    final rows = find.byType(BudgetCategoryRow);
    final visible = [
      for (var i = 0; i < rows.evaluate().length; i++)
        tester.getRect(rows.at(i)),
    ].where((r) => r.top >= tbbBottom && r.bottom <= visibleBottom);
    expect(visible.length, greaterThanOrEqualTo(7));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
