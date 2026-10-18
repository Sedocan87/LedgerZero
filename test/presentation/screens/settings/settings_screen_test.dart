import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/screens/settings/settings_screen.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/core/constants/app_icons.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:ledger_zero/core/money/currency.dart';
import 'package:ledger_zero/presentation/providers/settings_provider.dart';
import 'package:ledger_zero/presentation/screens/rules/rules_screen.dart';
import 'package:ledger_zero/presentation/providers/database_provider.dart';

import '../../../helpers/test_database.dart';

class MockGoRouter extends Mock implements GoRouter {}

Widget _app(SharedPreferences prefs) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: const MaterialApp(
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale('en', 'US')],
    home: SettingsScreen(),
  ),
);

void main() {
  testWidgets('Number format offers system, dot and comma', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    // Default is "follow language".
    expect(find.text('Follow language'), findsOneWidget);

    await tester.tap(find.text('Number Format'));
    await tester.pumpAndSettle();

    final dialog = find.byType(SimpleDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Follow language')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Dot (.)')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Comma (,)')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comma (,)'), findsOneWidget);
    expect(find.text('Follow language'), findsNothing);
    expect(prefs.getInt('settings_number_format'), AppNumberFormat.comma.index);
  });

  testWidgets('Currency picker lists every supported currency', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Currency'));
    await tester.pumpAndSettle();

    final dialog = find.byType(SimpleDialog);
    for (final code in supportedCurrencyCodes) {
      expect(
        find.descendant(of: dialog, matching: find.text(code)),
        findsOneWidget,
      );
    }
    await tester.tap(find.descendant(of: dialog, matching: find.text('CHF')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(container.read(settingsProvider).currency, 'CHF');
  });

  testWidgets('SettingsScreen shows Scheduled Transactions option', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en', 'US')],
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Scheduled Transactions'),
      500.0,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Scheduled Transactions'), findsOneWidget);
    expect(find.byIcon(AppIcons.calendar), findsOneWidget);
  });

  testWidgets('Rules and YNAB import are reachable from Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'rules',
              builder: (context, state) => const RulesScreen(),
            ),
            GoRoute(
              path: 'import-ynab',
              builder: (context, state) => const Text('ynab-import-screen'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rulesListProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The section is titled for what it holds (not "Manage Categories").
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings.rules')),
      200,
    );
    await tester.ensureVisible(find.byKey(const Key('settings.rules')));
    await tester.pumpAndSettle();
    expect(find.text('Manage data'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings.rules')));
    await tester.pumpAndSettle();
    expect(find.byType(RulesScreen), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('settings.importYnab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.importYnab')));
    await tester.pumpAndSettle();
    expect(find.text('ynab-import-screen'), findsOneWidget);
  });

  testWidgets('Default account and category offer only usable records', (
    tester,
  ) async {
    final t = TestDatabase();
    addTearDown(t.close);
    await t.addAccount(id: 'open', name: 'Giro');
    final old = await t.addAccount(id: 'old', name: 'Old card');
    await t.accounts.updateAccount(old.copyWith(isClosed: true));
    await t.addAccount(id: 'partner', name: 'Partner personal');
    await t.db.customStatement(
      'UPDATE accounts SET owner_id = ?, on_budget = 0 WHERE id = ?',
      ['partner-member', 'partner'],
    );
    final secret = (await t.categories.getCategoryById(
      await t.categoryId('Dining Out'),
    ))!;
    await t.categories.updateCategory(secret.copyWith(isHidden: true));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(t.db),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Default Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default Account'));
    await tester.pumpAndSettle();
    var dialog = find.byType(SimpleDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Giro')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Old card')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Partner personal')),
      findsNothing,
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Giro')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Default Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default Category'));
    await tester.pumpAndSettle();
    dialog = find.byType(SimpleDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Groceries')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Dining Out')),
      findsNothing,
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('None')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
