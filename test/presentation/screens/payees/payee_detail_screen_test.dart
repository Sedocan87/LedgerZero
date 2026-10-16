import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/payees/payee_detail_screen.dart';

import '../../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  final fmt = AppFormatter(
    locale: 'en',
    currency: 'GBP',
    decimalSeparator: '.',
  );
  final day = DateTime.utc(2026, 5, 4);

  setUp(() async {
    t = TestDatabase();
    await t.addAccount(id: 'eur', name: 'Euro', currency: 'EUR');
    await t.addAccount(id: 'usd', name: 'Dollar', currency: 'USD');
    await t.payees.createPayee(const Payee(id: 'p', name: 'Shop'));
  });

  tearDown(() => t.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          appFormatterProvider.overrideWithValue(fmt),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: PayeeDetailScreen(payeeId: 'p'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('amounts use the account currency; a split counts once', (
    tester,
  ) async {
    await t.addTransaction(
      id: 'split',
      accountId: 'eur',
      amount: -3000,
      date: day,
      payeeId: 'p',
    );
    for (final (id, amount) in [('c1', -1000), ('c2', -2000)]) {
      await t.addTransaction(
        id: id,
        accountId: 'eur',
        amount: amount,
        date: day,
        payeeId: 'p',
        parentTransactionId: 'split',
      );
    }
    await t.addTransaction(
      id: 'single',
      accountId: 'eur',
      amount: -1500,
      date: day,
      payeeId: 'p',
    );

    await pumpScreen(tester);

    // Two uses (split parent + single), 45.00 EUR spent.
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text(fmt.formatMoney(4500, currencyCode: 'EUR')),
      findsOneWidget,
    );
    expect(
      find.text(fmt.formatMoney(-1500, currencyCode: 'EUR')),
      findsOneWidget,
    );
    expect(
      find.text(fmt.formatMoney(-1500, currencyCode: 'GBP')),
      findsNothing,
    );

    await unmount(tester);
  });

  testWidgets('each row uses its own account currency', (tester) async {
    await t.addTransaction(
      id: 'e',
      accountId: 'eur',
      amount: -700,
      date: day,
      payeeId: 'p',
    );
    await t.addTransaction(
      id: 'u',
      accountId: 'usd',
      amount: -800,
      date: day,
      payeeId: 'p',
    );

    await pumpScreen(tester);

    expect(
      find.text(fmt.formatMoney(-700, currencyCode: 'EUR')),
      findsOneWidget,
    );
    expect(
      find.text(fmt.formatMoney(-800, currencyCode: 'USD')),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('list and stats refresh when transactions and the payee change', (
    tester,
  ) async {
    await t.addTransaction(
      id: 'first',
      accountId: 'eur',
      amount: -700,
      date: day,
      payeeId: 'p',
    );
    await pumpScreen(tester);
    expect(find.text('1'), findsOneWidget);
    expect(
      find.text(fmt.formatMoney(-700, currencyCode: 'EUR')),
      findsOneWidget,
    );

    // Written elsewhere (another screen, sync): no invalidation by hand.
    await tester.runAsync(
      () => t.addTransaction(
        id: 'second',
        accountId: 'eur',
        amount: -300,
        date: day,
        payeeId: 'p',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text(fmt.formatMoney(-300, currencyCode: 'EUR')),
      findsOneWidget,
    );
    expect(
      find.text(fmt.formatMoney(1000, currencyCode: 'EUR')),
      findsOneWidget,
    );

    await tester.runAsync(
      () => t.payees.updatePayee(const Payee(id: 'p', name: 'Corner Shop')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Corner Shop'), findsWidgets);

    await unmount(tester);
  });
}
