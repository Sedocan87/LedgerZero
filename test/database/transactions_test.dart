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

  test('transactions table should allow inserting data', () async {
    // We need an account first due to FK
    const account = AccountsCompanion(
      id: Value('acc_1'),
      name: Value('Checking'),
      type: Value('checking'),
    );
    await database.into(database.accounts).insert(account);

    final transaction = TransactionsCompanion(
      id: const Value('tx_1'),
      accountId: const Value('acc_1'),
      date: Value(DateTime(2025, 1, 15)),
      amount: const Value(-45.50),
      memo: const Value('Lunch'),
      createdAt: Value(DateTime.now()),
    );

    await database.into(database.transactions).insert(transaction);

    final result = await database.select(database.transactions).get();

    expect(result.length, 1);
    expect(result.first.id, 'tx_1');
    expect(result.first.amount, -45.50);
    expect(result.first.memo, 'Lunch');
    expect(result.first.date, DateTime(2025, 1, 15));
    expect(result.first.cleared, 0); // default
    expect(result.first.approved, true); // default
  });
}
