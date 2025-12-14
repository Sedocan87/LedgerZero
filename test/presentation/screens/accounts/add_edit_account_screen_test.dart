import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/screens/accounts/add_edit_account_screen.dart';
import 'package:ledger_zero/core/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAccountRepository implements AccountRepository {
  @override
  Future<void> createAccount(Account account) async {}

  @override
  Future<void> updateAccount(Account account) async {}

  @override
  Future<Account?> getAccountById(String id) async => null;

  @override
  Future<List<Account>> getAllAccounts() async => [];
  @override
  Stream<List<Account>> watchAllAccounts() => Stream.value([]);
  @override
  Stream<Account?> watchAccount(String id) => Stream.value(null);
  @override
  Future<void> deleteAccount(String id) async {}
}

void main() {
  testWidgets('AddEditAccountScreen form validation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: AddEditAccountScreen()),
      ),
    );

    // Scroll down to reveal button
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    // Tap save without entering data
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
    await tester.pumpAndSettle();

    // Scroll up to see error
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 500));
    await tester.pumpAndSettle();

    // Expect validation error
    expect(find.text('Please enter an account name'), findsOneWidget);
  });

  testWidgets('AddEditAccountScreen accessibility check', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWithValue(MockAccountRepository()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: AddEditAccountScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Check Semantics for Color Picker using exact string match
    expect(find.bySemanticsLabel('Color option 1'), findsOneWidget);
  });
}
