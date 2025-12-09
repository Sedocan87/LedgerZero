import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/screens/accounts/widgets/account_card.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('Account Widgets Tests', () {
    testWidgets('AccountCard displays account details correctly', (tester) async {
      final account = Account(
        id: '1',
        name: 'Checking Account',
        type: AccountType.checking,
        currentBalance: 1234.56,
        startingBalance: 0.0,
        createdAt: DateTime.now(),
      );

      await pumpTestWidget(
        tester,
        child: Scaffold(
          body: AccountCard(
            account: account,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Checking Account'), findsOneWidget);
      // Depending on locale, it might be $1,234.56 or 1.234,56 € etc.
      // But we know standard format for tests is often USD.
      // We can look for the digits.
      expect(find.textContaining('1,234.56'), findsOneWidget);
    });

    testWidgets('AccountCard triggers onTap when tapped', (tester) async {
      bool tapped = false;
      final account = Account(
        id: '1',
        name: 'Savings',
        type: AccountType.savings,
        currentBalance: 500.0,
        startingBalance: 0.0,
        createdAt: DateTime.now(),
      );

      await pumpTestWidget(
        tester,
        child: Scaffold(
          body: AccountCard(
            account: account,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.byType(AccountCard));
      expect(tapped, isTrue);
    });
  });
}
