// Widget tests of the quick-add screen (debounced parsing, stale results,
// double taps, small screens) on a real in-memory database.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';
import 'package:ledger_zero/presentation/screens/transactions/natural_language_input_screen.dart';
import 'package:ledger_zero/services/nlp/transaction_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

/// Answers each parse with [answer]; [calls] records the inputs.
class _ScriptedParser implements TransactionParser {
  _ScriptedParser(this.answer);

  final Future<ParsedTransaction> Function(String input) answer;
  final calls = <String>[];

  @override
  Future<ParsedTransaction> parse(String input) {
    calls.add(input);
    return answer(input);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ParsedTransaction _parsed(int amount) =>
    ParsedTransaction(amount: amount, confidence: 0.4);

void main() {
  late TestDatabase t;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    await t.addAccount(id: 'checking', name: 'Checking');
  });

  tearDown(() => t.close());

  Future<void> pump(
    WidgetTester tester,
    TransactionParser parser, {
    Size size = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = size;
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
              builder: (context, state) => const NaturalLanguageInputScreen(),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(t.db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          transactionParserProvider.overrideWithValue(parser),
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
  }

  /// Unmounts the tree (drift streams, timers) before the test ends.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<List<Transaction>> rows(WidgetTester tester) async =>
      (await tester.runAsync(() => t.transactions.getAllTransactions()))!;

  Finder input() => find.byType(TextField).first;

  testWidgets('parses only after a pause in typing', (tester) async {
    final parser = _ScriptedParser((_) async => _parsed(1500));
    await pump(tester, parser);

    for (final text in ['S', 'Sh', 'Sho', 'Shop 15']) {
      await tester.enterText(input(), text);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(parser.calls, isEmpty);

    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.pumpAndSettle();
    expect(parser.calls, ['Shop 15']);
    expect(find.textContaining('15.00'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a slower earlier parse does not overwrite a newer preview', (
    tester,
  ) async {
    final pending = <String, Completer<ParsedTransaction>>{};
    final parser = _ScriptedParser(
      (input) => (pending[input] = Completer<ParsedTransaction>()).future,
    );
    await pump(tester, parser);

    await tester.enterText(input(), 'Shop 1');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.enterText(input(), 'Shop 15');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    expect(parser.calls, ['Shop 1', 'Shop 15']);

    // The newer parse answers first, the older one afterwards.
    pending['Shop 15']!.complete(_parsed(1500));
    await tester.pumpAndSettle();
    expect(find.textContaining('15.00'), findsOneWidget);

    pending['Shop 1']!.complete(_parsed(100));
    await tester.pumpAndSettle();
    expect(find.textContaining('15.00'), findsOneWidget);
    expect(find.textContaining('1.00'), findsNothing);

    await unmount(tester);
  });

  testWidgets('a double tap on Create books one transaction', (tester) async {
    final parser = _ScriptedParser((_) async => _parsed(1500));
    await pump(tester, parser);

    await tester.enterText(input(), 'Shop 15');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(quickAddCreateKey));
    await tester.tap(find.byKey(quickAddCreateKey), warnIfMissed: false);
    await tester.pumpAndSettle();

    final saved = await rows(tester);
    expect(saved, hasLength(1));
    expect(saved.single.amount, -1500);
    expect(find.text('list'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('Create while a parse is pending saves the current text', (
    tester,
  ) async {
    final parser = _ScriptedParser(
      (input) async => _parsed(input == 'Shop 15' ? 1500 : 2000),
    );
    await pump(tester, parser);

    await tester.enterText(input(), 'Shop 15');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.pumpAndSettle();
    // Typed again; the preview is not updated yet.
    await tester.enterText(input(), 'Shop 20');
    await tester.tap(find.byKey(quickAddCreateKey));
    await tester.pumpAndSettle();

    expect((await rows(tester)).single.amount, -2000);

    await unmount(tester);
  });

  testWidgets('a closed account is neither preselected nor offered, and '
      'the booking goes into the open one (ledger F3)', (tester) async {
    // The closed account was created first and is a checking account: the
    // fallback choice used to pick it.
    await tester.runAsync(() async {
      await t.addAccount(
        id: 'savings',
        name: 'New Savings',
        type: AccountType.savings,
      );
      final old = (await t.accounts.getAccountById('checking'))!;
      await t.accounts.updateAccount(old.copyWith(isClosed: true));
    });
    final parser = _ScriptedParser((_) async => _parsed(500));
    await pump(tester, parser);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('New Savings'), findsOneWidget);
    expect(find.text('Checking'), findsNothing);

    await tester.tap(find.text('New Savings'));
    await tester.pumpAndSettle();
    expect(find.text('Checking'), findsNothing);
    await tester.tap(find.text('New Savings').last);
    await tester.pumpAndSettle();

    await tester.enterText(input(), 'coffee 5');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(quickAddCreateKey));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect((await rows(tester)).single.accountId, 'savings');

    await unmount(tester);
  });

  testWidgets('the preview shows the amount in the account\'s currency and '
      'says when a typed symbol is another one (UI F15)', (tester) async {
    var symbol = '€';
    final parser = _ScriptedParser(
      (_) async =>
          ParsedTransaction(amount: 1200, currency: symbol, confidence: 0.4),
    );
    await pump(tester, parser);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    // The account is in USD: "€12" is booked as 12.00 USD.
    await tester.enterText(input(), 'coffee €12');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.pumpAndSettle();
    expect(find.text(r'-$12.00'), findsOneWidget);
    expect(find.textContaining('€'), findsOneWidget); // the input only
    expect(find.byKey(const Key('quick_add_currency_note')), findsOneWidget);
    expect(
      find.text(
        'This account is in USD: the amount is booked in USD, not converted.',
      ),
      findsOneWidget,
    );

    // The account's own symbol needs no note.
    symbol = r'$';
    await tester.enterText(input(), r'coffee $12');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.pumpAndSettle();
    expect(find.text(r'-$12.00'), findsOneWidget);
    expect(find.byKey(const Key('quick_add_currency_note')), findsNothing);

    await unmount(tester);
  });

  testWidgets('fits a small phone with the keyboard open', (tester) async {
    final parser = _ScriptedParser(
      (_) async => ParsedTransaction(
        amount: 123456,
        date: DateTime(2025, 10, 17, 12),
        payeeName: 'Corner Shop',
        confidence: 0.8,
      ),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await pump(tester, parser, size: const Size(320, 640));

    await tester.enterText(input(), 'Shop 15');
    await tester.pump(NaturalLanguageInputScreen.parseDelay);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The buttons below the preview can be scrolled to.
    await tester.scrollUntilVisible(
      find.byKey(quickAddCreateKey),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(quickAddCreateKey).hitTestable(), findsOneWidget);

    await unmount(tester);
  });
}
