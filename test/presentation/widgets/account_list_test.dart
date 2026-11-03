import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/presentation/screens/accounts/widgets/account_card.dart';
import 'package:ledger_zero/presentation/widgets/common/account_avatar.dart';

import '../../widget_test_helpers.dart';

final _formatterOverride = appFormatterProvider.overrideWithValue(
  AppFormatter(locale: 'en', currency: 'USD', decimalSeparator: '.'),
);

void main() {
  group('Account Widgets Tests', () {
    testWidgets('AccountCard displays account details correctly', (
      tester,
    ) async {
      final account = Account(
        id: '1',
        name: 'Checking Account',
        type: AccountType.checking,
        balance: 123456,
        createdAt: DateTime.now(),
      );

      await pumpTestWidget(
        tester,
        overrides: [_formatterOverride],
        child: Scaffold(
          body: AccountCard(account: account, onTap: () {}),
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
        balance: 50000,
        createdAt: DateTime.now(),
      );

      await pumpTestWidget(
        tester,
        overrides: [_formatterOverride],
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
    Icon avatarIcon(WidgetTester tester) => tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('account.avatar')),
        matching: find.byType(Icon),
      ),
    );

    testWidgets('AccountCard shows the colour and icon picked in the editor', (
      tester,
    ) async {
      const account = Account(
        id: '1',
        name: 'Holiday',
        type: AccountType.checking,
        color: 0xFFE91E63,
        icon: 'Savings',
      );
      await pumpTestWidget(
        tester,
        overrides: [_formatterOverride],
        child: const Scaffold(body: AccountCard(account: account)),
      );

      final icon = avatarIcon(tester);
      expect(icon.icon, Icons.savings);
      expect(icon.color, const Color(0xFFE91E63));
    });

    testWidgets('AccountCard falls back to the type look when nothing is '
        'picked or only the old green-wallet default is stored', (
      tester,
    ) async {
      for (final account in const [
        Account(id: '1', name: 'Card', type: AccountType.credit),
        Account(
          id: '2',
          name: 'Card',
          type: AccountType.credit,
          color: legacyDefaultAccountColor,
          icon: legacyDefaultAccountIcon,
        ),
      ]) {
        await pumpTestWidget(
          tester,
          overrides: [_formatterOverride],
          child: Scaffold(body: AccountCard(account: account)),
        );
        expect(avatarIcon(tester).icon, Icons.credit_card_rounded);
        expect(avatarIcon(tester).color, isNot(const Color(0xFF4CAF50)));
      }
    });
  });
}
