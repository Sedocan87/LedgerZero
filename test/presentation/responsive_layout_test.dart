import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/l10n/app_localizations.dart';
import 'package:ledger_zero/presentation/screens/accounts/accounts_screen.dart';
import 'package:ledger_zero/presentation/screens/accounts/providers/account_list_provider.dart';
import 'package:ledger_zero/domain/entities/account.dart';

void main() {
  group('Responsive Layout', () {
    testWidgets('AccountsScreen constrains width on large screens', (tester) async {
      // Mock account data
      final accounts = [
        Account(
          id: '1',
          name: 'Test Account',
          type: AccountType.checking,
          currency: 'USD',
          startingBalance: 0,
          currentBalance: 100,
          isClosed: false,
          createdAt: DateTime.parse('2023-01-01'),
          updatedAt: DateTime.parse('2023-01-01'),
        ),
      ];

      // Use a large screen size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountListProvider.overrideWith((ref) => Stream.value(accounts)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AccountsScreen(),
          ),
        ),
      );

      // Verify ListView is wrapped in ConstrainedBox with maxWidth 800
      // We need to pumpAndSettle to let the AsyncValue load
      await tester.pumpAndSettle();

      final constrainedBoxFinder = find.byType(ConstrainedBox);
      expect(constrainedBoxFinder, findsWidgets); // Might find multiple, but we check specific one wrapping list

      // To be more precise, we can check if AccountCard is inside a constrained box.
      // Or just check if there is a ConstrainedBox with maxWidth 800
      bool found = false;
      final boxes = tester.widgetList<ConstrainedBox>(constrainedBoxFinder);
      for (var box in boxes) {
        if (box.constraints.maxWidth == 800.0) {
          found = true;
          break;
        }
      }
      expect(found, isTrue);
    });

    testWidgets('AccountsScreen fills width on small screens', (tester) async {
       // Mock account data
      final accounts = [
        Account(
          id: '1',
          name: 'Test Account',
          type: AccountType.checking,
          currency: 'USD',
          startingBalance: 0,
          currentBalance: 100,
          isClosed: false,
          createdAt: DateTime.parse('2023-01-01'),
          updatedAt: DateTime.parse('2023-01-01'),
        ),
      ];

      // Use a small screen size (mobile)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountListProvider.overrideWith((ref) => Stream.value(accounts)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AccountsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final constrainedBoxFinder = find.byType(ConstrainedBox);
      expect(constrainedBoxFinder, findsWidgets);
      bool found = false;
      final boxes = tester.widgetList<ConstrainedBox>(constrainedBoxFinder);
      for (var box in boxes) {
        if (box.constraints.maxWidth == 800.0) {
          found = true;
          break;
        }
      }
      expect(found, isTrue);
    });
  });
}
