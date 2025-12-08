import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:drift/drift.dart';

import 'test_utils.dart';

// Task 808: Stress tests (large datasets)
// Inserts 1000 transactions and checks database integrity.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Stress Test: Large Transaction Volume', (WidgetTester tester) async {
    final db = await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // Create Account
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(id: 'acc_stress', name: 'Stress Account', type: 'checking')
    );

    // Prepare 1000 transactions
    const count = 1000;
    final batch = <TransactionsCompanion>[];
    for (int i = 0; i < count; i++) {
      batch.add(
        TransactionsCompanion.insert(
          id: 'stress_tx_$i',
          accountId: 'acc_stress',
          date: DateTime.now().subtract(Duration(days: i % 365)),
          amount: (i % 2 == 0 ? -1 : 1) * (i.toDouble() + 1.0),
          memo: Value('Stress transaction $i'),
        )
      );
    }

    // Batch Insert
    await db.batch((batchOp) {
      batchOp.insertAll(db.transactions, batch);
    });

    // Verify
    final savedCount = (await db.select(db.transactions).get()).length;
    expect(savedCount, greaterThanOrEqualTo(count));

    await tester.pumpAndSettle();
  });
}
