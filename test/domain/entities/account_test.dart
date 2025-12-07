import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';

void main() {
  group('Account', () {
    final testDate = DateTime(2023, 1, 1);
    const testAccount = Account(
      id: '1',
      name: 'Checking',
      type: AccountType.checking,
      currency: 'USD',
      startingBalance: 100.0,
      currentBalance: 200.0,
      isClosed: false,
      color: 0xFF000000,
      icon: 'bank',
      notes: 'Test notes',
      // createdAt: testDate, // Cannot be const with non-const variable
    );

    // Re-create with dates for non-const tests
    final accountWithDates = Account(
      id: '1',
      name: 'Checking',
      type: AccountType.checking,
      currency: 'USD',
      startingBalance: 100.0,
      currentBalance: 200.0,
      isClosed: false,
      color: 0xFF000000,
      icon: 'bank',
      notes: 'Test notes',
      createdAt: testDate,
      updatedAt: testDate,
    );

    test('supports value equality', () {
      final account1 = Account(
        id: '1',
        name: 'Checking',
        type: AccountType.checking,
        currency: 'USD',
        startingBalance: 100.0,
        currentBalance: 200.0,
        isClosed: false,
        color: 0xFF000000,
        icon: 'bank',
        notes: 'Test notes',
        createdAt: testDate,
        updatedAt: testDate,
      );
      final account2 = Account(
        id: '1',
        name: 'Checking',
        type: AccountType.checking,
        currency: 'USD',
        startingBalance: 100.0,
        currentBalance: 200.0,
        isClosed: false,
        color: 0xFF000000,
        icon: 'bank',
        notes: 'Test notes',
        createdAt: testDate,
        updatedAt: testDate,
      );

      expect(account1, equals(account2));
      expect(account1.hashCode, equals(account2.hashCode));
    });

    test('copyWith returns new instance with updated fields', () {
      final updatedAccount = accountWithDates.copyWith(
        name: 'Savings',
        currentBalance: 300.0,
      );

      expect(updatedAccount.name, equals('Savings'));
      expect(updatedAccount.currentBalance, equals(300.0));
      expect(updatedAccount.id, equals(accountWithDates.id));
      expect(updatedAccount.type, equals(accountWithDates.type));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'id': '1',
        'name': 'Checking',
        'type': 'checking',
        'currency': 'USD',
        'starting_balance': 100.0,
        'current_balance': 200.0,
        'is_closed': false,
        'color': 0xFF000000,
        'icon': 'bank',
        'notes': 'Test notes',
        'created_at': testDate.toIso8601String(),
        'updated_at': testDate.toIso8601String(),
      };

      final account = Account.fromJson(json);
      expect(account, equals(accountWithDates));
    });

    test('toJson returns correct map', () {
      final json = accountWithDates.toJson();
      expect(json, {
        'id': '1',
        'name': 'Checking',
        'type': 'checking',
        'currency': 'USD',
        'starting_balance': 100.0,
        'current_balance': 200.0,
        'is_closed': false,
        'color': 0xFF000000,
        'icon': 'bank',
        'notes': 'Test notes',
        'created_at': testDate.toIso8601String(),
        'updated_at': testDate.toIso8601String(),
      });
    });

    test('validate returns errors for invalid fields', () {
      final invalidAccount = testAccount.copyWith(name: '', currency: 'US');
      final errors = invalidAccount.validate();

      expect(errors, contains('Account name cannot be empty'));
      expect(errors, contains('Currency code must be 3 characters'));
    });

    test('validate returns empty list for valid account', () {
      final errors = testAccount.validate();
      expect(errors, isEmpty);
    });

    test('defaults are set correctly', () {
        const defaultAccount = Account(id: '1', name: 'Test', type: AccountType.cash);
        expect(defaultAccount.currency, 'USD');
        expect(defaultAccount.startingBalance, 0.0);
        expect(defaultAccount.currentBalance, 0.0);
        expect(defaultAccount.isClosed, false);
    });
  });
}
