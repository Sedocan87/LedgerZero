// Widget tests of the transaction form on a real in-memory database.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/add_edit_transaction_screen.dart';
import 'package:ledger_zero/presentation/screens/transactions/natural_language_input_screen.dart';
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

class _FakeParser implements TransactionParser {
  _FakeParser(this.result);

  final ParsedTransaction result;

  @override
  Future<ParsedTransaction> parse(String input) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// testWidgets that disposes the widget tree (and with it the drift
/// stream subscriptions and the form's autosave timer) before the end.
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
  late String groceries;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_transaction_entry_intro': true,
    });
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
    );
    await t.addAccount(id: 'checking', name: 'Checking');
    await t.addAccount(id: 'savings', name: 'Savings');
    groceries = await t.categoryId('Groceries');
    await t.payees.createPayee(
      Payee(id: 'shop', name: 'Corner Shop', createdAt: DateTime.utc(2024)),
    );
  });

  tearDown(() => t.close());

  List<Override> overrides({AppFormatter? formatter}) => [
    databaseProvider.overrideWithValue(t.db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (formatter != null) appFormatterProvider.overrideWithValue(formatter),
  ];

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    AppFormatter? formatter,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('list', key: Key('list'))),
          routes: [GoRoute(path: 'form', builder: (context, state) => screen)],
        ),
      ],
      initialLocation: '/form',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(formatter: formatter),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<List<Transaction>> liveRows(WidgetTester tester) async =>
      (await tester.runAsync(() => t.transactions.getAllTransactions()))!;

  String fieldText(WidgetTester tester, String label) => tester
      .widget<AppTextField>(find.widgetWithText(AppTextField, label))
      .controller!
      .text;

  dbTestWidgets('shows an error when the amount is invalid', (tester) async {
    await pump(tester, const AddEditTransactionScreen());
    await tester.tap(find.widgetWithIcon(IconButton, Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid amount'), findsOneWidget);
  });

  dbTestWidgets('asks for an account', (tester) async {
    await pump(tester, const AddEditTransactionScreen());
    await tester.enterText(find.widgetWithText(AppTextField, 'Amount'), '100');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Please select an account'), findsOneWidget);
  });

  dbTestWidgets('transfer mode shows To Account and hides the payee', (
    tester,
  ) async {
    await pump(tester, const AddEditTransactionScreen());
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    expect(find.text('To Account'), findsOneWidget);
    expect(find.text('From Account'), findsOneWidget);
    expect(find.text('Payee'), findsNothing);
  });

  dbTestWidgets('saves "12,50" as 1250 minor units with a decimal comma', (
    tester,
  ) async {
    await pump(
      tester,
      const AddEditTransactionScreen(initialAccountId: 'checking'),
      formatter: AppFormatter(
        locale: 'de',
        currency: 'EUR',
        decimalSeparator: ',',
      ),
    );
    await tester.enterText(
      find.widgetWithText(AppTextField, 'Amount'),
      '12,50',
    );
    await tester.tap(find.text('Save & Add Another'));
    await tester.pumpAndSettle();

    final saved = (await liveRows(tester)).single;
    expect(saved.amount, -1250); // Outflow by default.
    expect(saved.accountId, 'checking');
    expect(saved.date.isUtc, isTrue);
    expect(saved.date.hour, 0);
  });

  dbTestWidgets('quick-add draft keeps payee, category and account', (
    tester,
  ) async {
    await pump(
      tester,
      AddEditTransactionScreen(
        draft: TransactionDraft(
          amountText: '5.00',
          payeeId: 'shop',
          payeeName: 'Corner Shop',
          categoryId: groceries,
          accountId: 'savings',
        ),
      ),
    );
    expect(fieldText(tester, 'Payee'), 'Corner Shop');
    expect(fieldText(tester, 'Category'), 'Groceries');
    expect(fieldText(tester, 'Account'), 'Savings');

    await tester.tap(find.widgetWithIcon(IconButton, Icons.check));
    await tester.pumpAndSettle();
    final saved = (await liveRows(tester)).single;
    expect(saved.payeeId, 'shop');
    expect(saved.categoryId, groceries);
    expect(saved.accountId, 'savings');
    expect(find.byKey(const Key('list')), findsOneWidget);
  });

  dbTestWidgets('edit mode shows the payee and lets the user clear it', (
    tester,
  ) async {
    final id = (await tester.runAsync(
      () => service.save(
        TransactionInput(
          accountId: 'checking',
          date: DateTime.utc(2024, 3, 1),
          amount: -500,
          payeeId: 'shop',
          categoryId: groceries,
        ),
      ),
    ))!.id;
    await pump(tester, AddEditTransactionScreen(transactionId: id));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'Payee'), 'Corner Shop');

    await tester.enterText(find.widgetWithText(AppTextField, 'Payee'), '');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.check));
    await tester.pumpAndSettle();
    final saved = (await liveRows(tester)).single;
    expect(saved.payeeId, isNull);
    expect(saved.categoryId, groceries);
  });

  dbTestWidgets('opening the receiving leg edits the transfer from its '
      'outflow leg and keeps the direction', (tester) async {
    final outId = (await tester.runAsync(
      () => service.save(
        TransactionInput(
          accountId: 'checking',
          date: DateTime.utc(2024, 3, 1),
          amount: -50000,
          transferAccountId: 'savings',
        ),
      ),
    ))!.id;
    final inId = (await liveRows(tester)).firstWhere((r) => r.id != outId).id;

    await pump(tester, AddEditTransactionScreen(transactionId: inId));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'From Account'), 'Checking');
    expect(fieldText(tester, 'To Account'), 'Savings');

    await tester.enterText(find.widgetWithText(AppTextField, 'Amount'), '600');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.check));
    await tester.pumpAndSettle();

    final rows = {for (final r in await liveRows(tester)) r.id: r};
    expect(rows, hasLength(2));
    expect(rows[outId]!.amount, -60000);
    expect(rows[inId]!.amount, 60000);
    expect(rows[inId]!.accountId, 'savings');
  });

  dbTestWidgets('quick-add "Edit details" replaces itself with the editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/quick-add',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('list')),
          routes: [
            GoRoute(
              path: 'quick-add',
              name: 'quick-add',
              builder: (context, state) => const NaturalLanguageInputScreen(),
            ),
            GoRoute(
              path: 'add-transaction',
              name: 'add-transaction',
              builder: (context, state) => AddEditTransactionScreen(
                draft: state.extra as TransactionDraft?,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides(),
          transactionParserProvider.overrideWithValue(
            _FakeParser(
              ParsedTransaction(
                amount: 1500,
                payeeId: 'shop',
                payeeName: 'Corner Shop',
                categoryId: groceries,
                confidence: 1,
              ),
            ),
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
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Shop 15');
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.editDetails));
    await tester.pumpAndSettle();

    expect(find.byType(NaturalLanguageInputScreen), findsNothing);
    expect(find.byType(AddEditTransactionScreen), findsOneWidget);
    expect(fieldText(tester, 'Payee'), 'Corner Shop');
    expect(fieldText(tester, 'Category'), 'Groceries');

    // Back goes to the list, not to the quick-add screen.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
  });
}
