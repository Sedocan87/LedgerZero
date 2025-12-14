import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';

void main() {
  testWidgets('ToBeBudgetedBanner displays positive amount in green', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tbbProvider.overrideWith((ref) => Future.value(100.0))],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ToBeBudgetedBanner()),
        ),
      ),
    );

    // Wait for the FutureProvider to resolve
    await tester.pumpAndSettle();

    final tbbTextFinder = find.text('\$100.00');
    expect(tbbTextFinder, findsOneWidget);

    final text = tester.widget<Text>(tbbTextFinder);
    expect(text.style?.color, Colors.green.shade700);
  });

  testWidgets(
    'ToBeBudgetedBanner displays negative amount in error color (red)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tbbProvider.overrideWith((ref) => Future.value(-50.0))],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ToBeBudgetedBanner()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final tbbTextFinder = find.text('-\$50.00');
      expect(tbbTextFinder, findsOneWidget);

      final text = tester.widget<Text>(tbbTextFinder);

      // We need to check against the theme's error color.
      // Since we didn't specify a theme, it uses default fallback.
      // Default Material 3 light theme error color is usually close to Colors.red.
      // To be precise, we can access the theme from the context in the test,
      // or just check if it matches the colorScheme.error of the MaterialApp.

      final context = tester.element(find.byType(ToBeBudgetedBanner));
      final expectedColor = Theme.of(context).colorScheme.error;

      expect(text.style?.color, expectedColor);
    },
  );
}
