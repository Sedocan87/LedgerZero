import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/reconciliation_screen.dart';

import '../../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  final fmt = AppFormatter(
    locale: 'de',
    currency: 'USD',
    decimalSeparator: ',',
  );
  String eur(int minor) => fmt.formatMoney(minor, currencyCode: 'EUR');

  final today = CalendarDate.today();

  setUp(() async {
    t = TestDatabase();
    await t.addAccount(id: 'a1', currency: 'EUR', startingBalance: 100000);
    // Cleared, before the statement date.
    await t.addTransaction(
      id: 'cleared-old',
      accountId: 'a1',
      amount: 5000,
      date: today.subtract(const Duration(days: 3)),
      cleared: TransactionClearStatus.cleared,
    );
    // Uncleared: part of the working balance only.
    await t.addTransaction(
      id: 'uncleared',
      accountId: 'a1',
      amount: -2000,
      date: today,
    );
    // Cleared, but after the statement date (today).
    await t.addTransaction(
      id: 'cleared-future',
      accountId: 'a1',
      amount: 700,
      date: today.add(const Duration(days: 5)),
      cleared: TransactionClearStatus.cleared,
    );
  });

  tearDown(() => t.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          appFormatterProvider.overrideWithValue(fmt),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReconciliationScreen(accountId: 'a1'),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Disposes the widget tree so drift's stream queries are cancelled
  /// before the database closes.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  String rowValue(WidgetTester tester, String key) {
    final row = find.byKey(Key(key));
    final texts = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .toList();
    return texts.last.data!;
  }

  Future<List<Transaction>> rows() =>
      t.transactions.getTransactionsByAccount('a1');

  testWidgets('shows working, cleared and cleared-up-to balances', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(rowValue(tester, 'reconcile.workingBalance'), eur(103700));
    expect(rowValue(tester, 'reconcile.clearedBalance'), eur(105700));
    // Up to today: the future cleared row is excluded.
    expect(rowValue(tester, 'reconcile.clearedUpTo'), eur(105000));
    expect(rowValue(tester, 'reconcile.difference'), '-');

    await tester.enterText(
      find.byKey(const Key('reconcile.statementBalance')),
      '1.062,50',
    );
    await tester.pump();
    expect(rowValue(tester, 'reconcile.difference'), eur(1250));

    await unmount(tester);
  });

  testWidgets('matching statement reconciles without an adjustment', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('reconcile.statementBalance')),
      '1.050,00',
    );
    await tester.pump();
    expect(rowValue(tester, 'reconcile.difference'), eur(0));

    await tester.tap(find.byKey(const Key('reconcile.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Discrepancy Found'), findsNothing);
    expect(
      find.text('1 transaction reconciled. The balance matches the statement.'),
      findsOneWidget,
    );
    // Screen closed.
    expect(find.byType(ReconciliationScreen), findsNothing);

    final byId = {for (final r in await rows()) r.id: r};
    expect(byId.length, 3);
    expect(byId['cleared-old']!.cleared, TransactionClearStatus.reconciled);
    expect(byId['cleared-future']!.cleared, TransactionClearStatus.cleared);
    expect(byId['uncleared']!.cleared, TransactionClearStatus.uncleared);

    await unmount(tester);
  });

  testWidgets('difference creates an uncategorised reconciled adjustment', (
    tester,
  ) async {
    await pumpScreen(tester);

    // Statement 1.062,50 -> 106250; cleared up to today is 105000.
    await tester.enterText(
      find.byKey(const Key('reconcile.statementBalance')),
      '1.062,50',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('reconcile.confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Discrepancy Found'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '1 transaction reconciled. An adjustment of ${eur(1250)} was created.',
      ),
      findsOneWidget,
    );

    final all = await rows();
    expect(all.length, 4);
    final adjustment = all.singleWhere(
      (r) => !{'cleared-old', 'uncleared', 'cleared-future'}.contains(r.id),
    );
    expect(adjustment.amount, 1250);
    expect(adjustment.categoryId, isNull);
    expect(adjustment.memo, 'Reconciliation balance adjustment');
    expect(adjustment.cleared, TransactionClearStatus.reconciled);
    expect(adjustment.date, today);
    expect(adjustment.date.isUtc, isTrue);
    expect(
      all.singleWhere((r) => r.id == 'cleared-old').cleared,
      TransactionClearStatus.reconciled,
    );

    // The cleared balance up to today now equals the statement.
    expect(await t.accounts.getClearedBalance('a1', upTo: today), 106250);

    await unmount(tester);
  });

  testWidgets('declining the adjustment changes nothing', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('reconcile.statementBalance')),
      '-10',
    );
    await tester.pump();
    expect(rowValue(tester, 'reconcile.difference'), eur(-1000 - 105000));

    await tester.tap(find.byKey(const Key('reconcile.confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(find.byType(ReconciliationScreen), findsOneWidget);
    final after = await rows();
    expect(
      after.where((r) => r.cleared == TransactionClearStatus.reconciled),
      isEmpty,
    );
    expect((await rows()).length, 3);

    await unmount(tester);
  });
}
