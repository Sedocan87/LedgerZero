import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/widgets/common/amount_text.dart';

void main() {
  final usd = AppFormatter(
    locale: 'en',
    currency: 'USD',
    decimalSeparator: '.',
  );
  final eurDe = AppFormatter(
    locale: 'de',
    currency: 'EUR',
    decimalSeparator: ',',
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    AppFormatter? formatter,
    Locale locale = const Locale('en'),
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [appFormatterProvider.overrideWithValue(formatter ?? usd)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  SemanticsNode nodeOf(WidgetTester tester) =>
      tester.getSemantics(find.byType(AmountText));

  testWidgets('positive available amount is read as "available"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const AmountText(5000, amountContext: AmountContext.available),
    );

    expect(find.text(r'$50.00'), findsOneWidget);
    expect(nodeOf(tester).label, r'$50.00 available');
    handle.dispose();
  });

  testWidgets('negative available amount is read as "overspent"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const AmountText(-1234, amountContext: AmountContext.available),
    );

    // Visible text keeps the sign; the spoken form uses the word instead.
    expect(find.text(r'-$12.34'), findsOneWidget);
    expect(nodeOf(tester).label, r'$12.34 overspent');
    handle.dispose();
  });

  testWidgets('raw glyphs are not read a second time', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const AmountText(5000, amountContext: AmountContext.available),
    );

    expect(find.bySemanticsLabel(r'$50.00'), findsNothing);
    expect(find.bySemanticsLabel(r'$50.00 available'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('transaction amounts are read as inflow / outflow', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const Column(
        children: [
          AmountText(2500, amountContext: AmountContext.transaction),
          AmountText(-999, amountContext: AmountContext.transaction),
        ],
      ),
    );

    expect(find.bySemanticsLabel(r'Inflow $25.00'), findsOneWidget);
    expect(find.bySemanticsLabel(r'Outflow $9.99'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('uses the account currency and the German wording', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const AmountText(
        -150000,
        amountContext: AmountContext.available,
        currencyCode: 'EUR',
      ),
      formatter: eurDe,
      locale: const Locale('de'),
    );

    final visible = eurDe.formatMoney(-150000, currencyCode: 'EUR');
    expect(find.text(visible), findsOneWidget);
    expect(
      nodeOf(tester).label,
      '${eurDe.formatMoney(150000, currencyCode: 'EUR')} überzogen',
    );
    handle.dispose();
  });

  test('amountSemanticsLabel covers every context', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    String label(int amount, AmountContext c) => amountSemanticsLabel(
      l10n: l10n,
      formatter: usd,
      amount: amount,
      amountContext: c,
    );

    expect(label(-100, AmountContext.none), r'-$1.00');
    expect(label(100, AmountContext.budgeted), r'$1.00 budgeted');
    expect(label(-100, AmountContext.activity), r'Activity -$1.00');
    expect(label(-100, AmountContext.balance), r'Balance -$1.00');
    expect(label(100, AmountContext.toBeBudgeted), r'$1.00 to be budgeted');
    expect(label(-100, AmountContext.toBeBudgeted), r'$1.00 overbudgeted');
    expect(label(0, AmountContext.available), r'$0.00 available');
  });
}
