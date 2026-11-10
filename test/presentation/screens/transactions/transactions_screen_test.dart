// Widget tests of the transaction list on a real in-memory database.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/data_providers.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/session_provider.dart';
import 'package:ledger_zero/presentation/providers/transactions_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/transactions_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/widgets/transaction_list_parts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

void dbTestWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;
  late TransactionService service;
  late String transferOut;
  final day = DateTime.utc(2024, 3, 15);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
    );
    await t.addAccount(id: 'checking', name: 'Checking');
    await t.addAccount(id: 'savings', name: 'Savings');
    await t.payees.createPayee(
      Payee(id: 'shop', name: 'Corner Shop', createdAt: DateTime.utc(2024)),
    );
    transferOut = (await service.save(
      TransactionInput(
        accountId: 'checking',
        date: day,
        amount: -50000,
        transferAccountId: 'savings',
      ),
    )).id;
    await service.save(
      TransactionInput(
        accountId: 'checking',
        date: day.subtract(const Duration(days: 1)),
        amount: -1234,
        payeeId: 'shop',
        categoryId: await t.categoryId('Groceries'),
      ),
    );
  });

  tearDown(() => t.close());

  Future<void> pump(
    WidgetTester tester, {
    FilteredTransactionsArgs? args,
    List<Override> extraOverrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...extraOverrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: TransactionsScreen(fixedFilter: args),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<Transaction>> liveRows(WidgetTester tester) async =>
      (await tester.runAsync(() => t.transactions.getAllTransactions()))!;

  dbTestWidgets('transfers show the other account instead of "No Payee"', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Transfer to Savings'), findsOneWidget);
    expect(find.text('Transfer from Checking'), findsOneWidget);
    expect(find.text('No Payee'), findsNothing);
  });

  dbTestWidgets('swipe delete asks first, deletes both legs and undo '
      'restores both', (tester) async {
    await pump(tester);
    await tester.drag(find.text('Transfer to Savings'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete transaction?'), findsOneWidget);
    expect(
      find.textContaining('The other side of the transfer is deleted too.'),
      findsOneWidget,
    );

    // Cancel keeps everything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await liveRows(tester), hasLength(3));

    await tester.drag(find.text('Transfer to Savings'), const Offset(600, 0));
    await tester.pumpAndSettle();
    // The dialog's button (the swipe strip behind the row says "Delete"
    // too).
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    final remaining = await liveRows(tester);
    expect(remaining, hasLength(1));
    expect(remaining.single.payeeId, 'shop');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final restored = await liveRows(tester);
    expect(restored, hasLength(3));
    expect(restored.map((r) => r.id), contains(transferOut));
  });

  dbTestWidgets('bulk delete deletes the counterpart too', (tester) async {
    await pump(tester);
    await tester.longPress(find.text('Transfer from Checking'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete transaction?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await liveRows(tester), hasLength(1));
  });

  dbTestWidgets('search matches the payee name and the amount', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'corner');
    // The query runs once typing pauses for the debounce interval.
    await tester.pump(TransactionsNotifier.searchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('Corner Shop'), findsOneWidget);
    expect(find.text('Transfer to Savings'), findsNothing);

    await tester.enterText(find.byType(TextField), '500');
    await tester.pump(TransactionsNotifier.searchDebounce);
    await tester.pumpAndSettle();
    expect(find.text('Corner Shop'), findsNothing);
    expect(find.text('Transfer to Savings'), findsOneWidget);
  });

  group('fourth audit', () {
    Finder appBarTitle(String text) =>
        find.descendant(of: find.byType(AppBar), matching: find.text(text));

    dbTestWidgets('back leaves selection mode, then search mode, before it '
        'leaves the screen (UI F11)', (tester) async {
      await pump(tester);
      await tester.longPress(find.text('Transfer to Savings'));
      await tester.pumpAndSettle();
      expect(appBarTitle('1 selected'), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(appBarTitle('1 selected'), findsNothing);
      expect(appBarTitle('Transactions'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'corner');
      await tester.pump(TransactionsNotifier.searchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('Transfer to Savings'), findsNothing);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      // The search is gone with its mode.
      expect(find.text('Transfer to Savings'), findsOneWidget);

      // Nothing left to close: back is the system's again.
      expect(await tester.binding.handlePopRoute(), isFalse);
    });

    dbTestWidgets('approving by swipe offers Undo (ledger improvement 3)', (
      tester,
    ) async {
      await tester.runAsync(
        () => service.save(
          TransactionInput(
            accountId: 'checking',
            date: day,
            amount: -700,
            newPayeeName: 'Bakery',
            approved: false,
          ),
        ),
      );
      await pump(tester);
      Future<bool> approved() async => (await liveRows(
        tester,
      )).singleWhere((r) => r.amount == -700).approved;

      await tester.drag(find.text('Bakery'), const Offset(-600, 0));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(await approved(), isTrue);
      expect(find.text('Transaction approved'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(await approved(), isFalse);
    });

    dbTestWidgets('the swipe actions are labelled', (tester) async {
      await pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Corner Shop')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(find.text('Delete'), findsOneWidget);
      await gesture.moveBy(const Offset(-480, 0));
      await tester.pump();
      expect(find.text('Approve'), findsOneWidget);
      await gesture.moveBy(const Offset(240, 0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    dbTestWidgets('the active sort is marked in the menu and announced '
        'above the list; the rows follow it', (tester) async {
      await pump(tester);
      // Newest first is the default and needs no note.
      expect(find.byKey(const Key('transactions.sortNote')), findsNothing);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(PopupMenuItem<TransactionSortField>, 'Date'),
          matching: find.byIcon(Icons.arrow_downward),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithText(PopupMenuItem<TransactionSortField>, 'Amount'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sorted by Amount, ascending'), findsOneWidget);
      // Lowest amount first, across days: the transfer out (-500.00, the
      // later day) comes before the shop (-12.34) and the transfer in.
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(top('Transfer to Savings'), lessThan(top('Corner Shop')));
      expect(top('Corner Shop'), lessThan(top('Transfer from Checking')));

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<TransactionSortField>, 'Date'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sorted by Date, ascending'), findsOneWidget);
      // Oldest day first.
      expect(top('Corner Shop'), lessThan(top('Transfer to Savings')));
    });

    dbTestWidgets('"select all" on a paged list says that it covers the '
        'loaded rows only', (tester) async {
      await tester.runAsync(() async {
        for (var i = 0; i < TransactionsNotifier.pageSize; i++) {
          await t.addTransaction(
            accountId: 'checking',
            amount: -100 - i,
            date: DateTime.utc(2024, 1, 1),
          );
        }
      });
      await pump(tester);
      await tester.longPress(find.text('Transfer to Savings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all loaded'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'The 50 loaded transactions are selected. Scroll down to load more.',
        ),
        findsOneWidget,
      );
      expect(find.text('50 selected'), findsOneWidget);
    });

    dbTestWidgets('"select all" on a fully loaded list says nothing', (
      tester,
    ) async {
      await pump(tester);
      await tester.longPress(find.text('Transfer to Savings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('flattenByDay', () {
    Transaction row(String id, int day, int amount) => Transaction(
      id: id,
      accountId: 'a',
      date: DateTime.utc(2024, 3, day),
      amount: amount,
    );

    test('by date: one header per day, in the order of the rows', () {
      final rows = [row('a', 1, -1), row('b', 1, -2), row('c', 2, -3)];
      expect(
        flattenByDay(
          rows,
          sort: const TransactionSort(field: TransactionSortField.date),
        ),
        [
          DateTime.utc(2024, 3, 1),
          rows[0],
          rows[1],
          DateTime.utc(2024, 3, 2),
          rows[2],
        ],
      );
    });

    test('any other order keeps the rows as they are, without headers', () {
      final rows = [row('a', 2, -1), row('b', 1, -2), row('c', 2, -3)];
      expect(
        flattenByDay(
          rows,
          sort: const TransactionSort(field: TransactionSortField.amount),
        ),
        rows,
      );
    });
  });

  dbTestWidgets('a fixed-filter list never persists its filter', (
    tester,
  ) async {
    final args = FilteredTransactionsArgs(
      filter: TransactionFilter(categoryIds: [await t.categoryId('Groceries')]),
      title: 'Groceries',
    );
    await pump(tester, args: args);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('Corner Shop'), findsOneWidget);
    expect(find.text('Transfer to Savings'), findsNothing);
    expect(prefs.getString('tx_filter'), isNull);
  });

  dbTestWidgets('a failing lookup (e.g. while the app locks) does not throw '
      'in build', (tester) async {
    await pump(
      tester,
      extraOverrides: [
        categoryMapProvider.overrideWithValue(
          const AsyncValue.error(DatabaseLockedException(), StackTrace.empty),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Transfer to Savings'), findsOneWidget);
  });
}
