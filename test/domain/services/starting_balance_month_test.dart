// A starting balance is dated by the calendar month the user created the
// account in (the local day), not by the UTC month of `created_at`.
//
// The two instants below differ from their UTC month in one direction each,
// so the test tells the two apart in every time zone but UTC itself:
//
//   TZ=America/Los_Angeles flutter test test/domain/services/starting_balance_month_test.dart
//   TZ=Europe/Berlin flutter test test/domain/services/starting_balance_month_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';

import '../../helpers/test_database.dart';
import 'ledger_test_helpers.dart';

void main() {
  late TestDatabase t;

  final oct = DateTime.utc(2026, 10, 1);
  final nov = DateTime.utc(2026, 11, 1);

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  Future<void> createAccount(String id, DateTime createdAtLocal) =>
      t.accounts.createAccount(
        Account(
          id: id,
          name: id,
          type: AccountType.checking,
          currency: 'USD',
          startingBalance: 200000,
          onBudget: true,
          createdAt: createdAtLocal.toUtc(),
        ),
      );

  test(
    'an account created on the evening of the last day of a month counts '
    'in that month (west of UTC the instant is already next month)',
    () async {
      // 31 October, 20:00 on the user's clock.
      await createAccount('evening', DateTime(2026, 10, 31, 20));

      expect(await t.budgeting.calculateTBB(oct), 200000);
      expect(await t.budgeting.calculateTBB(nov), 200000);

      // Budgeting it in October leaves both months at 1,000.00.
      final groceries = await t.categoryId('Groceries');
      await t.budgeting.setCategoryBudgetedAmount(groceries, 100000, oct);
      expect(await t.budgeting.calculateTBB(oct), 100000);
      expect(await t.budgeting.calculateTBB(nov), 100000);

      await expectLedgerInvariant(t, oct);
      await expectLedgerInvariant(t, nov);
    },
  );

  test(
    'an account created just after midnight on the 1st does not count in '
    'the month before (east of UTC the instant is still last month)',
    () async {
      // 1 November, 00:30 on the user's clock.
      await createAccount('night', DateTime(2026, 11, 1, 0, 30));

      expect(await t.budgeting.calculateTBB(oct), 0);
      expect(await t.budgeting.calculateTBB(nov), 200000);

      await expectLedgerInvariant(t, oct);
      await expectLedgerInvariant(t, nov);
    },
  );

  test('a transaction dated before the creation day still moves the start '
      'back to its month', () async {
    await createAccount('backdated', DateTime(2026, 11, 1, 0, 30));
    await t.addTransaction(
      accountId: 'backdated',
      amount: -5000,
      date: DateTime.utc(2026, 10, 31),
    );

    expect(await t.budgeting.calculateTBB(oct), 195000);
    await expectLedgerInvariant(t, oct);
    await expectLedgerInvariant(t, nov);
  });
}
