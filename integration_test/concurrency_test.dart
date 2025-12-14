import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:drift/drift.dart';

import 'test_utils.dart';

// Task 805: Test concurrent operations
// This test attempts to perform multiple DB operations concurrently to ensure no locking issues.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Concurrent Database Operations Test', (
    WidgetTester tester,
  ) async {
    final db = await setupIntegrationTest(tester);
    await completeOnboarding(tester);

    // FIX: Create the account FIRST to satisfy Foreign Key constraints
    // Awaiting here ensures account exists before transactions are inserted.
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'acc_concurrent',
            name: 'Conc Account',
            type: 'cash',
          ),
        );

    // Create a lot of futures to insert transactions concurrently
    final futures = <Future>[];
    for (int i = 0; i < 50; i++) {
      futures.add(
        db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: 'concurrent_tx_$i',
                accountId: 'acc_concurrent', // Now this account exists
                date: DateTime.now(),
                amount: 10.0 + i,
              ),
              mode: InsertMode.insertOrReplace,
            )
            .catchError((e) {
              // ignore: avoid_print
              print('Concurrent insert error: $e');
              return 0;
            }),
      );
    }

    // Run all inserts
    await Future.wait(futures);

    // Verify count
    final count = await db.select(db.transactions).get();

    // Filter by our test IDs
    final testTxs = count
        .where((t) => t.id.startsWith('concurrent_tx_'))
        .length;
    expect(testTxs, 50, reason: 'All concurrent inserts should succeed');
  });
}
