// The envelope-budgeting explainer is reachable from Help and closes with
// "Got it" (it is no longer an onboarding step).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/settings/budget_basics_screen.dart';
import 'package:ledger_zero/presentation/screens/settings/help_screen.dart';

void main() {
  testWidgets('Help opens Budgeting basics; Got it returns', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const HelpScreen(),
          routes: [
            GoRoute(
              path: 'budget-basics',
              name: 'budget-basics',
              builder: (_, _) => const BudgetBasicsScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('help.budgetBasics')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetBasicsScreen), findsOneWidget);
    expect(find.text('Give Every Dollar a Job'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await tester.tap(find.byKey(const Key('budgetBasics.done')));
    await tester.pumpAndSettle();
    expect(find.byType(BudgetBasicsScreen), findsNothing);
    expect(find.byType(HelpScreen), findsOneWidget);
  });
}
