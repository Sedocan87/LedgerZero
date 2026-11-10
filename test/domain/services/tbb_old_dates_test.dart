// To Be Budgeted has no lower date bound: a row dated before 1970 (only
// reachable by an import with a mis-parsed year) counts like any other, as
// it does in category activity and account balances.
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';
import 'ledger_test_helpers.dart';

void main() {
  late TestDatabase t;

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  test('uncategorised rows dated before 1970 count in To Be Budgeted', () async {
    final month = DateTime.utc(2026, 11, 1);
    final account = (await t.addAccount(startingBalance: 100000)).id;
    await t.addTransaction(
      accountId: account,
      amount: 2500,
      date: DateTime.utc(1969, 12, 31),
    );
    await t.addTransaction(
      accountId: account,
      amount: -700,
      date: DateTime.utc(26, 3, 4),
    );

    expect(await t.budgeting.calculateTBB(month), 100000 + 2500 - 700);
    await expectLedgerInvariant(t, month);
    await expectLedgerInvariant(t, DateTime.utc(1969, 12, 1));
  });
}
