// The budget row with real font metrics.
//
// Widget tests normally lay text out with the square test font, which says
// nothing about whether "1.234,56 €" fits a cell on a phone. This test
// loads Roboto (bundled under assets/fonts for the PDF reports, and the
// font Android draws the app with) and lays the row out at the two common
// phone widths, 360 dp and 412 dp.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/budget_category_row.dart';

Future<void> loadRoboto() async {
  Future<ByteData> font(String name) async {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final loader = FontLoader('Roboto')
    ..addFont(font('Roboto-Regular.ttf'))
    ..addFont(font('Roboto-Bold.ttf'));
  await loader.load();
}

void main() {
  setUpAll(loadRoboto);

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
        overrides: [
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'de', currency: 'EUR', decimalSeparator: ','),
          ),
        ],
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
            body: SingleChildScrollView(
              // As in BudgetCategoryList: 16 dp page padding and a card.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(
                    children: [
                      for (final vm in rows) BudgetCategoryRow(viewModel: vm),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The texts on screen that were cut off (ellipsis or dropped lines).
  List<String> cutOff(WidgetTester tester) => [
    for (final p in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    ))
      if (p.didExceedMaxLines) p.text.toPlainText(),
  ];

  /// The smallest factor by which an amount on screen was shrunk to fit
  /// its cell (1.0: none was).
  double smallestAmountScale(WidgetTester tester) {
    var smallest = 1.0;
    for (final p in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    )) {
      if (p.text.toPlainText().contains(RegExp(r'\d'))) {
        final scale = p.getTransformTo(null).getMaxScaleOnAxis();
        if (scale < smallest) {
          smallest = scale;
        }
      }
    }
    return smallest;
  }

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

  test('the test really measures with Roboto, not the square test font', () {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'iiii',
        style: TextStyle(fontFamily: 'Roboto', fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Four test-font squares would be 56 wide.
    expect(painter.width, lessThan(20));
    painter.dispose();
  });

  for (final width in [360.0, 412.0]) {
    testWidgets('at $width dp four- and five-digit amounts are shown in full', (
      tester,
    ) async {
      await pumpRows(
        tester,
        width: width,
        rows: [
          // 1.234,56 € budgeted, -987,65 € spent, 246,91 € left.
          row(
            'Miete/Kredit',
            budgeted: 123456,
            activity: -98765,
            available: 24691,
          ),
          // 12.345,67 € in every column.
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
      expect(cutOff(tester), isEmpty);
      // At full size, not shrunk to fit.
      expect(smallestAmountScale(tester), closeTo(1.0, 0.001));
    });

    testWidgets('at $width dp the seeded German names are shown in full', (
      tester,
    ) async {
      await pumpRows(
        tester,
        width: width,
        rows: [
          for (final name in germanNames)
            row(name, budgeted: 123456, activity: -98765, available: 24691),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(cutOff(tester), isEmpty);
    });
  }

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
    final amounts = cutOff(tester).where((t) => t.contains(RegExp(r'\d')));
    expect(amounts, isEmpty);
    // Shrunk to fit where needed, but never below the size they have at
    // the normal text scale.
    expect(smallestAmountScale(tester) * 1.3, greaterThanOrEqualTo(1.0));
  });
}
