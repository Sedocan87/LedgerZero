import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';

void main() {
  group('Account', () {
    test('should instantiate correctly', () {
      final account = Account(
        id: '1',
        name: 'Test Account',
        type: AccountType.checking,
        currency: 'EUR',
        startingBalance: 100.0,
        currentBalance: 200.0,
        isClosed: true,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 2),
      );

      expect(account.id, '1');
      expect(account.name, 'Test Account');
      expect(account.type, AccountType.checking);
      expect(account.currency, 'EUR');
      expect(account.startingBalance, 100.0);
      expect(account.currentBalance, 200.0);
      expect(account.isClosed, true);
      expect(account.createdAt, DateTime(2023, 1, 1));
      expect(account.updatedAt, DateTime(2023, 1, 2));
    });

    test('should use default values', () {
      const account = Account(
        id: '2',
        name: 'Default Account',
        type: AccountType.savings,
      );

      expect(account.id, '2');
      expect(account.name, 'Default Account');
      expect(account.type, AccountType.savings);
      expect(account.currency, 'USD');
      expect(account.startingBalance, 0.0);
      expect(account.currentBalance, 0.0);
      expect(account.isClosed, false);
      expect(account.createdAt, null);
      expect(account.updatedAt, null);
    });
  });
}
