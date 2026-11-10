// The shared transaction row: badge, labels, amount colours and fit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/app/theme.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/domain/entities/category.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';

void main() {
  Transaction tx({int amount = -4250, String? transferAccountId}) =>
      Transaction(
        id: 't',
        accountId: 'a',
        date: DateTime.utc(2026, 11, 10),
        amount: amount,
        transferAccountId: transferAccountId,
      );

  Future<void> pump(
    WidgetTester tester,
    Widget row, {
    double width = 392,
    double textScale = 1,
    ThemeData? theme,
    String locale = 'en',
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFormatterProvider.overrideWithValue(
            locale == 'de'
                ? AppFormatter(
                    locale: 'de',
                    currency: 'EUR',
                    decimalSeparator: ',',
                  )
                : AppFormatter(
                    locale: 'en',
                    currency: 'USD',
                    decimalSeparator: '.',
                  ),
          ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: ListView(children: [row])),
        ),
      ),
    );
    await tester.pump();
  }

  Icon badgeIcon(WidgetTester tester) => tester.widget<Icon>(
    find.descendant(
      of: find.byKey(const Key('transaction.badge')),
      matching: find.byType(Icon),
    ),
  );

  Text amountText(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text));

  testWidgets('a categorised row: coloured badge, "Category · Account", '
      'outflow with a minus in the text colour', (tester) async {
    await pump(
      tester,
      TransactionListItem(
        transaction: tx(),
        payeeName: 'REWE',
        categoryName: 'Groceries',
        category: const Category(id: 'c', name: 'Groceries'),
        accountName: 'Girokonto',
        showDate: false,
      ),
    );
    expect(find.text('REWE'), findsOneWidget);
    expect(find.text('Groceries · Girokonto'), findsOneWidget);
    expect(badgeIcon(tester).icon, Icons.local_grocery_store);
    expect(
      badgeIcon(tester).color,
      isNot(AppTheme.lightTheme.colorScheme.onSurfaceVariant),
    );
    expect(
      amountText(tester, r'-$42.50').style!.color,
      AppTheme.lightTheme.colorScheme.onSurface,
    );
    expect(
      amountText(tester, r'-$42.50').style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    // Under a day heading the row shows no date.
    expect(find.textContaining('2026'), findsNothing);
  });

  testWidgets('an inflow is signed and green; the date shows when asked', (
    tester,
  ) async {
    await pump(
      tester,
      TransactionListItem(transaction: tx(amount: 250000), payeeName: 'Salary'),
    );
    final text = amountText(tester, r'+$2,500.00');
    // The theme's success colour (contrast-tested in theme_test.dart).
    expect(
      text.style!.color,
      AppTheme.lightTheme.extension<AppSemanticColors>()!.success,
    );
    expect(find.textContaining('2026'), findsOneWidget);
    // No category: the default tag icon on a neutral badge.
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(badgeIcon(tester).icon, defaultCategoryIcon);
    expect(
      badgeIcon(tester).color,
      AppTheme.lightTheme.colorScheme.onSurfaceVariant,
    );
  });

  testWidgets('a transfer and a split get their own neutral icons', (
    tester,
  ) async {
    await pump(
      tester,
      TransactionListItem(
        transaction: tx(transferAccountId: 'b'),
        payeeName: 'Transfer to Savings',
        categoryName: 'Transfer',
        // A category on a transfer leg (never shown) does not win.
        category: const Category(id: 'c', name: 'Groceries'),
      ),
    );
    expect(badgeIcon(tester).icon, Icons.swap_horiz_rounded);

    await pump(
      tester,
      TransactionListItem(
        transaction: tx(),
        payeeName: 'IKEA',
        categoryName: 'Split',
        isSplit: true,
      ),
    );
    expect(badgeIcon(tester).icon, Icons.call_split_rounded);
  });

  testWidgets('a selected row in multi-select has a tonal highlight and a '
      'checked box instead of the badge', (tester) async {
    await pump(
      tester,
      TransactionListItem(
        transaction: tx(),
        payeeName: 'REWE',
        isSelectionMode: true,
        isSelected: true,
      ),
    );
    expect(find.byKey(const Key('transaction.badge')), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    final highlight = tester.widget<Material>(
      find
          .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
          .first,
    );
    expect(highlight.color, AppTheme.lightTheme.colorScheme.secondaryContainer);
    // No cleared toggle while selecting.
    expect(find.byType(IconButton), findsNothing);
  });

  for (final (width, scale) in [(360.0, 1.3), (320.0, 1.0), (392.0, 2.0)]) {
    testWidgets('long German labels and a large amount fit at $width dp, '
        'text scale $scale', (tester) async {
      await pump(
        tester,
        TransactionListItem(
          transaction: tx(amount: -1234567),
          payeeName: 'Hausverwaltung Mustermann & Söhne GmbH',
          categoryName: 'Reparaturen Wohnung',
          category: const Category(id: 'c', name: 'Reparaturen Wohnung'),
          accountName: 'Gemeinsames Girokonto',
          onClearStatusChanged: (_) {},
        ),
        width: width,
        textScale: scale,
        locale: 'de',
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('-12.345,67'), findsOneWidget);
      // The payee keeps a readable share of the row.
      expect(
        tester.getSize(find.textContaining('Hausverwaltung')).width,
        greaterThan(width * 0.2),
      );
    });
  }
}
