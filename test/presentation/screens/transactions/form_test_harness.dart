// Shared set-up of the transaction form widget tests: a real in-memory
// database, mock preferences and a router with a list route below the form.
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
import 'package:ledger_zero/presentation/widgets/common/app_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

/// testWidgets that disposes the widget tree (and with it the drift
/// stream subscriptions and the form's autosave timer) before the end.
void dbTestWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}

/// Accounts `checking` and `savings`, the seeded categories and the payee
/// `shop` ("Corner Shop").
class FormHarness {
  late TestDatabase t;
  late SharedPreferences prefs;
  late TransactionService service;
  late String groceries;
  late GoRouter router;

  Future<void> setUp() async {
    SharedPreferences.setMockInitialValues({
      'tutorial_completed_transaction_entry_intro': true,
    });
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
    groceries = await t.categoryId('Groceries');
    await t.payees.createPayee(
      Payee(id: 'shop', name: 'Corner Shop', createdAt: DateTime.utc(2024)),
    );
  }

  Future<void> tearDown() => t.close();

  /// Shows [screen] at `/form`, above a list route at `/`.
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    router = GoRouter(
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
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overrides,
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await settle(tester);
  }

  /// Lets database reads finish and the frames after them build.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<List<Transaction>> liveRows(WidgetTester tester) async =>
      (await tester.runAsync(() => t.transactions.getAllTransactions()))!;

  String fieldText(WidgetTester tester, String label) => tester
      .widget<AppTextField>(find.widgetWithText(AppTextField, label))
      .controller!
      .text;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(IconButton, Icons.check));
    await settle(tester);
  }
}
