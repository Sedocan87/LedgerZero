import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/budget_provider.dart';
import 'package:ledger_zero/presentation/screens/budget/widgets/to_be_budgeted_banner.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';

void main() {
  testWidgets('ToBeBudgetedBanner renders correctly with value', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tbbProvider.overrideWith((ref) => Future.value(123.45)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ToBeBudgetedBanner()),
        ),
      ),
    );

    // Wait for FutureProvider to resolve
    await tester.pumpAndSettle();

    expect(find.byType(ToBeBudgetedBanner), findsOneWidget);
    // Check for localized label
    expect(find.text('To Be Budgeted'), findsOneWidget);
    // Check for formatted amount (default locale is usually en_US in tests)
    // $123.45
    expect(find.text('\$123.45'), findsOneWidget);
  });
}
