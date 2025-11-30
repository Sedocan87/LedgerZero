import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('scheduled_transactions table should allow inserting data', () async {
    final scheduledTx = ScheduledTransactionsCompanion(
      id: const Value('sch_1'),
      amount: const Value(100.0),
      frequency: const Value('monthly'),
      nextDate: Value(DateTime.now()),
      autoApprove: const Value(false),
    );

    await database.into(database.scheduledTransactions).insert(scheduledTx);

    final result = await database.select(database.scheduledTransactions).get();

    expect(result.length, 1);
    expect(result.first.id, 'sch_1');
    expect(result.first.amount, 100.0);
    expect(result.first.frequency, 'monthly');
    expect(result.first.accountId, null);
    expect(result.first.autoApprove, false);
  });

  test('scheduled_transactions table should allow referencing account, payee, and category', () async {
    // Create referenced entities
    await database.into(database.accounts).insert(
      const AccountsCompanion(
        id: Value('acc_1'),
        name: Value('Checking'),
        type: Value('checking'),
      ),
    );
    await database.into(database.categories).insert(
      const CategoriesCompanion(
        id: Value('cat_1'),
        name: Value('Utilities'),
      ),
    );
    await database.into(database.payees).insert(
      const PayeesCompanion(
        id: Value('payee_1'),
        name: Value('Electric Co'),
      ),
    );

    const scheduledTx = ScheduledTransactionsCompanion(
      id: Value('sch_2'),
      accountId: Value('acc_1'),
      categoryId: Value('cat_1'),
      payeeId: Value('payee_1'),
      amount: Value(50.0),
    );

    await database.into(database.scheduledTransactions).insert(scheduledTx);

    final result = await database.select(database.scheduledTransactions).get();

    expect(result.length, 1);
    expect(result.first.accountId, 'acc_1');
    expect(result.first.categoryId, 'cat_1');
    expect(result.first.payeeId, 'payee_1');
  });
}
