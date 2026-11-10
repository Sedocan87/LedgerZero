import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/card_payments.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/account_detail_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_item.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_parts.dart';

import '../../../domain/services/ledger_test_helpers.dart';
import '../../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  final day = DateTime.utc(2026, 3, 10);

  setUp(() async {
    t = TestDatabase();
    await t.addAccount(id: 'a', name: 'Checking', startingBalance: 100000);
    await t.addAccount(id: 'b', name: 'Savings', startingBalance: 5000);
    await addTransfer(
      t,
      id: 'a-to-b',
      from: 'a',
      to: 'b',
      amount: 1000,
      date: day,
    );
    await addTransfer(
      t,
      id: 'b-to-a',
      from: 'b',
      to: 'a',
      amount: 400,
      date: day,
    );
    await t.scheduledTransactions.createScheduledTransaction(
      ScheduledTransaction(
        id: 'sched',
        accountId: 'b',
        amount: -100,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: DateTime.utc(2026, 4, 1),
      ),
    );
  });

  tearDown(() => t.close());

  Future<void> pumpScreen(WidgetTester tester, String accountId) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/account'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/account',
          builder: (_, _) => AccountDetailScreen(accountId: accountId),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          appFormatterProvider.overrideWithValue(
            AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();
  }

  testWidgets('a credit card shows its payment category: set aside and '
      'still missing', (tester) async {
    await tester.runAsync(() async {
      await t.addAccount(
        id: 'visa',
        name: 'Visa',
        type: AccountType.credit,
        startingBalance: -20000,
      );
      await t.budgeting.setCategoryBudgetedAmount(
        CardPayments.categoryId('visa'),
        5000,
        CalendarDate.startOfMonthUtc(CalendarDate.today()),
      );
    });
    await pumpScreen(tester, 'visa');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account.cardPayment')), findsOneWidget);
    expect(find.text('Set aside to pay the card: \$50.00'), findsOneWidget);
    expect(find.text('Still missing: \$150.00'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a checking account has no payment category', (tester) async {
    await pumpScreen(tester, 'a');
    expect(find.byKey(const Key('account.cardPayment')), findsNothing);
    await unmount(tester);
  });

  testWidgets('transfers show the other account and direction', (tester) async {
    await pumpScreen(tester, 'a');

    expect(find.text('Transfer to Savings'), findsOneWidget);
    expect(find.text('Transfer from Savings'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('(UI refresh) the list uses the shared rows under a heading '
      'per day with its total', (tester) async {
    await t.addTransaction(
      id: 'meter',
      accountId: 'a',
      amount: -250,
      date: DateTime.utc(2026, 3, 9),
    );
    await t.db.customStatement(
      "UPDATE transactions SET memo = 'Parking meter' WHERE id = 'meter'",
    );
    await pumpScreen(tester, 'a');

    expect(find.byType(TransactionListItem), findsNWidgets(3));
    Finder total(DateTime date) => find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is TransactionDateHeader && w.date == date,
      ),
      matching: find.byKey(const Key('transactions.dayTotal')),
    );
    // -10.00 out, +4.00 in.
    expect(
      find.descendant(of: total(day), matching: find.text(r'-$6.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: total(DateTime.utc(2026, 3, 9)),
        matching: find.text(r'-$2.50'),
      ),
      findsOneWidget,
    );
    // Without a payee the memo names the row; a transfer reads "Transfer".
    expect(find.text('Parking meter'), findsOneWidget);
    expect(find.text('Transfer'), findsNWidgets(2));
    // The date is in the heading, not on the rows.
    expect(
      find.descendant(
        of: find.byType(TransactionListItem),
        matching: find.textContaining('2026'),
      ),
      findsNothing,
    );

    await unmount(tester);
  });

  testWidgets('delete dialog explains consequences and offers closing', (
    tester,
  ) async {
    await pumpScreen(tester, 'b');
    await openDeleteDialog(tester);

    expect(find.textContaining('close the account instead'), findsOneWidget);
    expect(
      find.textContaining('scheduled transactions. This cannot be undone'),
      findsOneWidget,
    );
    expect(
      find.textContaining('normal uncategorized transactions'),
      findsOneWidget,
    );

    await tester.tap(find.text('Close account instead'));
    await tester.pumpAndSettle();
    // (L3) A schedule books into this account: the user is told first.
    expect(
      find.byKey(const Key('closeAccount.schedulesWarning')),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 scheduled transaction uses this account'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Close Account'));
    await tester.pumpAndSettle();

    expect((await t.accounts.getAccountById('b'))!.isClosed, isTrue);
    expect(await countRows(t, 'transactions', 'account_id = ?', ['b']), 2);
    expect(find.text('Account closed'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('delete permanently removes the account safely', (tester) async {
    await pumpScreen(tester, 'b');
    await openDeleteDialog(tester);

    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(await t.accounts.getAccountById('b'), isNull);
    expect(find.byType(AccountDetailScreen), findsNothing);
    expect(
      find.text(
        'Account deleted. 2 transfers in other accounts are now normal '
        'transactions.',
      ),
      findsOneWidget,
    );
    expect(
      await t.scheduledTransactions.getScheduledTransactionById('sched'),
      isNull,
    );
    expect(
      await column(t, 'transactions', 'a-to-b-out', 'transfer_account_id'),
      isNull,
    );
    expect(
      await column(t, 'transactions', 'b-to-a-in', 'transfer_account_id'),
      isNull,
    );
    await expectLedgerInvariant(t, DateTime.utc(2026, 3));
    await expectNoForeignKeyViolations(t);

    await unmount(tester);
  });

  testWidgets('(L3) closing from the menu warns about schedules and cancel '
      'keeps the account open', (tester) async {
    await pumpScreen(tester, 'b');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close Account'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('closeAccount.schedulesWarning')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await t.accounts.getAccountById('b'))!.isClosed, isFalse);

    // An account without schedules closes without the question.
    await unmount(tester);
    await pumpScreen(tester, 'a');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close Account'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('closeAccount.schedulesWarning')),
      findsNothing,
    );
    expect((await t.accounts.getAccountById('a'))!.isClosed, isTrue);
    await unmount(tester);
  });

  testWidgets('(ledger improvement 1) the list is paged like the '
      'Transactions tab and loads more when scrolled', (tester) async {
    await t.addAccount(id: 'c', name: 'Busy');
    for (var i = 0; i < 60; i++) {
      await t.addTransaction(
        accountId: 'c',
        amount: -100 - i,
        date: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
      );
    }
    await pumpScreen(tester, 'c');
    int loaded() => ProviderScope.containerOf(
      tester.element(find.byType(TransactionList)),
    ).read(accountTransactionsProvider('c')).transactions.valueOrNull!.length;
    expect(loaded(), 50);

    final more = find.byKey(const Key('account.transactions.more'));
    final list = find.descendant(
      of: find.byType(TransactionList),
      matching: find.byType(Scrollable),
    );
    // Scrolled to the end of the loaded page, the next one is requested.
    for (var i = 0; i < 10; i++) {
      await tester.drag(list, const Offset(0, -800));
      await tester.pump();
    }
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(loaded(), 60);
    expect(more, findsNothing);

    await unmount(tester);
  });
}
