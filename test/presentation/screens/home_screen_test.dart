import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/presentation/screens/home_screen.dart';
import 'package:ledger_zero/presentation/widgets/home/to_be_budgeted_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/dashboard_stats_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/recent_transactions_widget.dart';
import 'package:ledger_zero/presentation/widgets/home/home_empty_state.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';

void main() {
  testWidgets('HomeScreen shows dashboard when accounts exist', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final transactionDate = DateTime(2023, 10, 25);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          hasAccountsProvider.overrideWith((ref) => Future.value(true)),
          tbbProvider.overrideWith((ref, month) => Future.value(100.0)),
          monthlyStatsProvider.overrideWith(
            (ref, month) =>
                Future.value({'income': 2000.0, 'spending': -500.0}),
          ),
          recentTransactionsProvider.overrideWith(
            (ref) => Stream.value([
              Transaction(
                id: '1',
                accountId: 'a1',
                date: transactionDate,
                amount: -15.50,
                approved: true,
                isDeleted: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                memo: 'Coffee',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en', 'US')],
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ToBeBudgetedWidget), findsOneWidget);
    expect(find.byType(HomeEmptyState), findsNothing);
  });

  testWidgets('HomeScreen shows EmptyState when no accounts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          hasAccountsProvider.overrideWith((ref) => Future.value(false)),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en', 'US')],
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeEmptyState), findsOneWidget);
    expect(find.text('Welcome to LedgerZero'), findsOneWidget);
    expect(find.byType(ToBeBudgetedWidget), findsNothing);
  });

  testWidgets('HomeScreen renders correctly on tablet size', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final transactionDate = DateTime(2023, 10, 25);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          hasAccountsProvider.overrideWith((ref) => Future.value(true)),
          tbbProvider.overrideWith((ref, month) => Future.value(100.0)),
          monthlyStatsProvider.overrideWith(
            (ref, month) =>
                Future.value({'income': 2000.0, 'spending': -500.0}),
          ),
          recentTransactionsProvider.overrideWith(
            (ref) => Stream.value([
              Transaction(
                id: '1',
                accountId: 'a1',
                date: transactionDate,
                amount: -15.50,
                approved: true,
                isDeleted: false,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                memo: 'Coffee',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('en', 'US')],
          home: HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    // Ensure widgets are still present
    expect(find.byType(DashboardStatsWidget), findsOneWidget);
    expect(find.byType(RecentTransactionsWidget), findsOneWidget);
  });
}
