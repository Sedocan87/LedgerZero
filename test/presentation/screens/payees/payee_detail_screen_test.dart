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

  testWidgets('auto category and default account can be set back to None', (
    tester,
  ) async {
    final category = (await t.categories.getAllCategories()).first;
    await t.payees.updatePayee(
      Payee(
        id: 'p',
        name: 'Shop',
        autoCategoryId: category.id,
        defaultAccountId: 'eur',
      ),
    );
    await pumpScreen(tester);

    await tester.tap(find.byKey(ValueKey('cat_${category.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    final afterCategory = await tester.runAsync(
      () => t.payees.getPayeeById('p'),
    );
    expect(afterCategory!.autoCategoryId, isNull);
    expect(afterCategory.defaultAccountId, 'eur');

    await tester.tap(find.byKey(const ValueKey('acc_eur')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    final afterAccount = await tester.runAsync(
      () => t.payees.getPayeeById('p'),
    );
    expect(afterAccount!.defaultAccountId, isNull);

    await unmount(tester);
  });

  testWidgets('a small screen with the keyboard open scrolls instead of '
      'overflowing', (tester) async {
    for (var i = 0; i < 12; i++) {
      await t.addTransaction(
        id: 't$i',
        accountId: 'eur',
        amount: -100 * (i + 1),
        date: day,
        payeeId: 'p',
      );
    }
    await pumpScreen(tester);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The notes field and the transactions below it are reachable.
    final notes = find.widgetWithText(TextFormField, 'Notes');
    await tester.ensureVisible(notes);
    await tester.pumpAndSettle();
    await tester.tap(notes);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(fmt.formatMoney(-1200, currencyCode: 'EUR')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);

    await unmount(tester);
  });

  group('rename (ledger F6)', () {
    /// The screen pushed above a home route, so leaving it can be seen.
    Future<void> pumpPushed(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(t.db),
            appFormatterProvider.overrideWithValue(fmt),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Text('home', key: Key('home')),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const PayeeDetailScreen(payeeId: 'p'),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Lets the database work started by a tap finish.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
      }
    }

    Future<void> renameTo(WidgetTester tester, String name) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        name,
      );
      await tester.tap(find.byTooltip('Save'));
      await settle(tester);
    }

    testWidgets('a name another payee has is refused; Merge merges into '
        'that payee', (tester) async {
      await t.payees.createPayee(const Payee(id: 'other', name: 'Corner'));
      await t.addTransaction(
        id: 'tx',
        accountId: 'eur',
        amount: -100,
        date: day,
        payeeId: 'p',
      );
      await pumpPushed(tester);
      await renameTo(tester, 'corner');
      expect(find.byKey(const Key('payee.nameTaken')), findsOneWidget);
      expect(
        (await tester.runAsync(() => t.payees.getPayeeById('p')))!.name,
        'Shop',
      );

      await tester.tap(find.byKey(const Key('payee.nameTaken.merge')));
      await settle(tester);
      expect(find.byKey(const Key('home')), findsOneWidget);
      expect(await t.payees.getPayeeById('p'), isNull);
      expect((await t.transactions.getTransactionById('tx'))!.payeeId, 'other');
      await unmount(tester);
    });

    testWidgets('a free name is saved', (tester) async {
      await pumpPushed(tester);
      await renameTo(tester, 'Shop North');
      expect(find.byKey(const Key('payee.nameTaken')), findsNothing);
      expect(
        (await tester.runAsync(() => t.payees.getPayeeById('p')))!.name,
        'Shop North',
      );
      await unmount(tester);
    });
  });
}
