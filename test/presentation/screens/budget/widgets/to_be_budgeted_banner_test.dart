import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';

void main() {
  Widget buildBanner(int tbb) {
    return ProviderScope(
      overrides: [
        tbbProvider.overrideWith((ref, month) => Future.value(tbb)),
        appFormatterProvider.overrideWithValue(
          AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ToBeBudgetedBanner()),
      ),
    );
  }

  testWidgets('ToBeBudgetedBanner displays positive amount in green', (
    tester,
  ) async {
    await tester.pumpWidget(buildBanner(10000));

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
      await tester.pumpWidget(buildBanner(-5000));

      await tester.pumpAndSettle();

      final tbbTextFinder = find.text('-\$50.00');
      expect(tbbTextFinder, findsOneWidget);

      final text = tester.widget<Text>(tbbTextFinder);

      final context = tester.element(find.byType(ToBeBudgetedBanner));
      final expectedColor = Theme.of(context).colorScheme.error;

      expect(text.style?.color, expectedColor);
    },
  );

  testWidgets('ToBeBudgetedBanner shows an exact zero without a sign', (
    tester,
  ) async {
    await tester.pumpWidget(buildBanner(0));
    await tester.pumpAndSettle();

    expect(find.text('\$0.00'), findsOneWidget);
    expect(find.text('-\$0.00'), findsNothing);
  });
}
