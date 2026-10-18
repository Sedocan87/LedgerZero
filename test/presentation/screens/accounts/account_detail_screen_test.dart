import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/account_detail_screen.dart';

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

  testWidgets('transfers show the other account and direction', (tester) async {
    await pumpScreen(tester, 'a');

    expect(find.text('Transfer to Savings'), findsOneWidget);
    expect(find.text('Transfer from Savings'), findsOneWidget);

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
}
