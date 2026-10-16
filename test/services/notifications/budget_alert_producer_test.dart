import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/services/notifications/budget_alert_producer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

class _Alert {
  _Alert(this.categoryId, this.title, this.body);
  final String categoryId;
  final String title;
  final String body;
}

void main() {
  // Mid-March 2024 (local); transactions are dated in that month.
  final now = DateTime(2024, 3, 20, 12);
  final march = DateTime.utc(2024, 3, 1);
  final day = DateTime.utc(2024, 3, 15);

  late TestDatabase t;
  late SharedPreferences prefs;
  late List<_Alert> alerts;
  late bool enabled;
  late bool showAmounts;
  late String checking;
  late String groceries;
  late String rent;

  BudgetAlertProducer producer({
    Future<int> Function(String, DateTime)? available,
  }) => BudgetAlertProducer(
    prefs: prefs,
    categoryAvailable: available ?? t.budgeting.calculateCategoryAvailable,
    notify:
        ({
          required String categoryId,
          required String title,
          required String body,
        }) async => alerts.add(_Alert(categoryId, title, body)),
    enabled: () => enabled,
    showAmounts: () => showAmounts,
    categoryName: (id) async => (await t.categories.getCategoryById(id))?.name,
    now: () => now,
  );

  TransactionService service(BudgetAlertProducer p) => TransactionService(
    transactionRepository: t.transactions,
    payeeRepository: t.payees,
    undoService: UndoService(),
    unitOfWork: t.unitOfWork,
    onSaved: (change) => p.onSaved(change.before, change.after),
  );

  Future<String> spend(
    TransactionService s,
    int amount, {
    String? categoryId,
    DateTime? date,
  }) async => (await s.save(
    TransactionInput(
      accountId: checking,
      date: date ?? day,
      amount: amount,
      categoryId: categoryId ?? groceries,
    ),
  )).id;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    t = TestDatabase();
    alerts = [];
    enabled = true;
    showAmounts = false;
    checking = (await t.addAccount(name: 'Checking')).id;
    groceries = await t.categoryId('Groceries');
    rent = await t.categoryId('Electric');
    await t.budgeting.setCategoryBudgetedAmount(groceries, 10000, march);
  });

  tearDown(() => t.close());

  test('notifies once when an outflow makes available negative', () async {
    final s = service(producer());
    await spend(s, -6000);
    expect(alerts, isEmpty, reason: 'still 40.00 available');

    await spend(s, -5000);
    expect(alerts, hasLength(1));
    expect(alerts.single.categoryId, groceries);

    // Still overspent: not again this month.
    await spend(s, -100);
    expect(alerts, hasLength(1));
    expect(
      prefs.getBool(BudgetAlertProducer.keyFor(groceries, '2024-03')),
      isTrue,
    );
  });

  test('alerts again in a new month and forgets old months', () async {
    await prefs.setBool(BudgetAlertProducer.keyFor(groceries, '2024-02'), true);
    await prefs.setBool(BudgetAlertProducer.keyFor(groceries, '2024-03'), true);
    final s = service(producer());
    await spend(s, -20000);
    expect(alerts, isEmpty, reason: 'already alerted in March');
    expect(
      prefs.getBool(BudgetAlertProducer.keyFor(groceries, '2024-02')),
      isNull,
    );
  });

  test('does nothing when the setting is off', () async {
    enabled = false;
    await spend(service(producer()), -20000);
    expect(alerts, isEmpty);
    expect(prefs.getKeys(), isEmpty);
  });

  test('ignores inflows', () async {
    // Rent has nothing budgeted; an inflow into it is never an alert, even
    // while the category is negative from elsewhere.
    final calls = <String>[];
    final s = service(
      producer(
        available: (id, month) async {
          calls.add(id);
          return -1;
        },
      ),
    );
    await spend(s, 5000, categoryId: rent);
    expect(alerts, isEmpty);
    expect(calls, isEmpty);
  });

  test('ignores outflows dated after the current month', () async {
    await spend(service(producer()), -20000, date: DateTime.utc(2024, 4, 2));
    expect(alerts, isEmpty);
  });

  test('editing an outflow to a smaller amount does not alert', () async {
    final s = service(producer());
    final id = await spend(s, -9000);
    final calls = <String>[];
    final watching = service(
      producer(
        available: (id, month) async {
          calls.add(id);
          return -1;
        },
      ),
    );
    await watching.save(
      TransactionInput(
        id: id,
        accountId: checking,
        date: day,
        amount: -8000,
        categoryId: groceries,
      ),
    );
    expect(calls, isEmpty);
  });

  test('uses generic text unless amounts are opted in', () async {
    await spend(service(producer()), -20000);
    final alert = alerts.single;
    expect(alert.body, isNot(contains('Groceries')));
    expect(alert.body, isNot(contains('100')));
    expect(alert.title, isNot(contains('Groceries')));
  });

  test('names the category and the overspent amount when opted in', () async {
    showAmounts = true;
    await spend(service(producer()), -25000);
    final body = alerts.single.body;
    expect(body, contains('Groceries'));
    expect(body, contains('15000'), reason: 'overspent by 150.00');
  });

  test('passes no details to the text builder unless opted in', () async {
    final seen = <BudgetAlertDetails?>[];
    BudgetAlertProducer withText() => BudgetAlertProducer(
      prefs: prefs,
      categoryAvailable: (_, _) async => -500,
      notify:
          ({
            required String categoryId,
            required String title,
            required String body,
          }) async {},
      enabled: () => true,
      showAmounts: () => showAmounts,
      categoryName: (_) async => 'Fun',
      text: (details) {
        seen.add(details);
        return (title: 'T', body: 'B');
      },
      now: () => now,
    );
    await spend(service(withText()), -100);
    showAmounts = true;
    await spend(service(withText()), -100, categoryId: rent);
    expect(seen, [null, (categoryName: 'Fun', overspent: 500)]);
  });

  test('a failing producer never fails the save', () async {
    final s = service(
      producer(available: (_, _) async => throw StateError('boom')),
    );
    final id = await spend(s, -20000);
    expect(await t.transactions.getTransactionById(id), isNotNull);
    expect(alerts, isEmpty);
  });

  test('a throwing hook never fails the save', () async {
    final s = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
      onSaved: (_) => throw StateError('hook failed'),
    );
    final id = await spend(s, -100);
    expect(await t.transactions.getTransactionById(id), isNotNull);

    final async = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
      onSaved: (_) async => throw StateError('hook failed'),
    );
    final id2 = await spend(async, -100);
    expect(await t.transactions.getTransactionById(id2), isNotNull);
  });
}
