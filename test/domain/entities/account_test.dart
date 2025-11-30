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

    test('should support serialization', () {
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

      final json = account.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'Test Account');
      expect(json['type'], 'checking');
      expect(json['currency'], 'EUR');
      expect(json['starting_balance'], 100.0);
      expect(json['current_balance'], 200.0);
      expect(json['is_closed'], true);
      expect(json['created_at'], account.createdAt?.toIso8601String());
      expect(json['updated_at'], account.updatedAt?.toIso8601String());

      final fromJson = Account.fromJson(json);
      expect(fromJson.id, account.id);
      expect(fromJson.name, account.name);
      expect(fromJson.type, account.type);
      expect(fromJson.currency, account.currency);
      expect(fromJson.startingBalance, account.startingBalance);
      expect(fromJson.currentBalance, account.currentBalance);
      expect(fromJson.isClosed, account.isClosed);
      expect(fromJson.createdAt, account.createdAt);
      expect(fromJson.updatedAt, account.updatedAt);
    });

    test('should handle missing optional fields during serialization', () {
      final json = {
        'id': '1',
        'name': 'Test Account',
        'type': 'checking',
      };

      final account = Account.fromJson(json);
      expect(account.id, '1');
      expect(account.name, 'Test Account');
      expect(account.type, AccountType.checking);
      expect(account.currency, 'USD'); // Default
      expect(account.startingBalance, 0.0); // Default
      expect(account.currentBalance, 0.0); // Default
      expect(account.isClosed, false); // Default
      expect(account.createdAt, isNull);
      expect(account.updatedAt, isNull);
    });

    test('should support equality', () {
      final account1 = Account(
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

      final account2 = Account(
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

      const account3 = Account(
        id: '2',
        name: 'Other Account',
        type: AccountType.savings,
      );

      // Reflexive
      expect(account1, equals(account1));

      // Symmetric
      expect(account1, equals(account2));
      expect(account2, equals(account1));

      // HashCode
      expect(account1.hashCode, equals(account2.hashCode));

      // Not Equal
      expect(account1, isNot(equals(account3)));
      expect(account1, isNot(equals('Not an Account')));
      expect(account1, isNot(equals(null)));
    });
  });
}
