import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/rule.dart';
import 'package:ledger_zero/domain/entities/rules/rule_action.dart';
import 'package:ledger_zero/domain/entities/rules/rule_condition.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/category_repository.dart'
    show cardPaymentHealStamp;
import 'package:ledger_zero/domain/services/transaction_service_types.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:ledger_zero/presentation/providers/service_providers.dart';

/// The demo household (store screenshots): six months of a zero-based
/// budget in dollars, relative to today, so it never looks stale.
///
/// Written through the app's own services (transfers, card payment
/// categories, payee learning), so every number follows the real budget
/// rules. Payees are fictional. The current month ends with exactly
/// [demoToBeBudgeted] to assign.
const int demoToBeBudgeted = 24000;

const _checking = 'demo-checking';
const _savings = 'demo-savings';
const _visa = 'demo-visa';
const _brokerage = 'demo-brokerage';

/// Monthly budget per category (minor units).
const Map<String, int> _plan = {
  'Rent/Mortgage': 165000,
  'Electric': 9000,
  'Water': 4000,
  'Internet': 6000,
  'Groceries': 62000,
  'Transportation': 16000,
  'Medical': 4000,
  'Auto Maintenance': 5000,
  'Home Maintenance': 4000,
  'Renter\'s/Home Insurance': 2400,
  'Software Subscriptions': 1000,
  'Car Payment': 35000,
  'Fitness': 3900,
  'Education': 3000,
  'Dining Out': 22000,
  'Entertainment': 6000,
  'Vacation': 20000,
  'Gaming': 2000,
  'Music': 1100,
  'Fun Money': 10000,
  'Savings': 60000,
  'Stocks & ETFs': 40000,
};

Future<void> seedDemoData(ProviderContainer c) async {
  final accounts = c.read(accountRepositoryProvider);
  final categories = c.read(categoryRepositoryProvider);
  final budgeting = c.read(budgetingServiceProvider);
  final tx = c.read(transactionServiceProvider);

  final today = CalendarDate.today();
  final thisMonth = CalendarDate.startOfMonthUtc(today);
  DateTime monthAt(int offset) =>
      DateTime.utc(thisMonth.year, thisMonth.month + offset);
  final first = monthAt(-5);

  // Accounts: created at the start of the first month, so the starting
  // balances count there.
  final created = DateTime.utc(first.year, first.month, 1, 12);
  for (final a in [
    Account(
      id: _checking,
      name: 'Checking',
      type: AccountType.checking,
      startingBalance: 140000,
      createdAt: created,
    ),
    Account(
      id: _visa,
      name: 'Visa Card',
      type: AccountType.credit,
      // Debt from before LedgerZero: still to cover, not charged to TBB.
      startingBalance: -38000,
      createdAt: created,
    ),
    Account(
      id: _savings,
      name: 'Savings',
      type: AccountType.savings,
      startingBalance: 650000,
      onBudget: false,
      createdAt: created,
    ),
    Account(
      id: _brokerage,
      name: 'Brokerage',
      type: AccountType.investment,
      startingBalance: 2480000,
      onBudget: false,
      createdAt: created,
    ),
  ]) {
    await accounts.createAccount(a);
  }
  await categories.syncCardPaymentCategories(stampedAt: cardPaymentHealStamp);

  final ids = {
    for (final cat in await categories.getAllCategories()) cat.name: cat.id,
  };
  String cat(String name) => ids[name]!;

  final random = Random(11);
  int around(int amount, int spread) =>
      amount + random.nextInt(spread * 2 + 1) - spread;

  Future<void> add(
    String account,
    DateTime date,
    int amount,
    String payee,
    String? category, {
    String? transferTo,
    String? memo,
  }) async {
    if (date.isAfter(today)) {
      return; // later this month: not happened yet
    }
    final recent = today.difference(date).inDays < 3;
    await tx.save(
      TransactionInput(
        accountId: account,
        date: date,
        amount: amount,
        newPayeeName: transferTo == null ? payee : null,
        categoryId: category == null ? null : cat(category),
        memo: memo,
        transferAccountId: transferTo,
        cleared: recent
            ? TransactionClearStatus.uncleared
            : TransactionClearStatus.cleared,
        counterpartCleared: recent
            ? TransactionClearStatus.uncleared
            : TransactionClearStatus.cleared,
      ),
      recordUndo: false,
    );
  }

  var cardSpentLastMonth = 38000; // the first payment clears the old debt
  for (var offset = -5; offset <= 0; offset++) {
    final m = monthAt(offset);
    DateTime day(int d) => DateTime.utc(m.year, m.month, d);
    var cardSpent = 0;
    Future<void> card(int d, int cents, String payee, String category) async {
      if (!day(d).isAfter(today)) {
        cardSpent += cents;
      }
      await add(_visa, day(d), -cents, payee, category);
    }

    // Budget for the month.
    for (final MapEntry(:key, :value) in _plan.entries) {
      await budgeting.setCategoryBudgetedAmount(cat(key), value, m);
    }
    if (offset == -5) {
      // The card debt from before LedgerZero, covered in the first month.
      await budgeting.setCategoryBudgetedAmount(cat('Visa Card'), 38000, m);
    }

    // Income: twice a month.
    await add(_checking, day(1), 260000, 'Northwind Labs', null);
    await add(_checking, day(15), 260000, 'Northwind Labs', null);

    // Bills from checking.
    await add(
      _checking,
      day(1),
      -165000,
      'Parkside Apartments',
      'Rent/Mortgage',
    );
    await add(
      _checking,
      day(1),
      -2400,
      'Harbor Insurance',
      'Renter\'s/Home Insurance',
    );
    await add(_checking, day(3), -3900, 'Peak Fitness', 'Fitness');
    await add(_checking, day(5), -35000, 'Summit Auto Loan', 'Car Payment');
    await add(_checking, day(6), -around(8600, 900), 'City Power', 'Electric');
    await add(_checking, day(8), -5999, 'FiberNet', 'Internet');
    await add(_checking, day(12), -around(3500, 400), 'Metro Water', 'Water');

    // Savings and investing.
    await add(_checking, day(2), -60000, '', 'Savings', transferTo: _savings);
    await add(
      _checking,
      day(16),
      -40000,
      '',
      'Stocks & ETFs',
      transferTo: _brokerage,
    );

    // Pay last month's card bill.
    await add(
      _checking,
      day(21),
      -cardSpentLastMonth,
      '',
      null,
      transferTo: _visa,
    );

    // Everyday spending on the card.
    const grocers = ['Green Grocer', 'Corner Market', 'FreshMart'];
    for (final (i, d) in [2, 6, 9, 13, 17, 20, 24, 28].indexed) {
      await card(d, around(7400, 2600), grocers[i % 3], 'Groceries');
    }
    for (final d in [4, 11, 19, 26]) {
      await card(d, around(3900, 900), 'Fuel Stop', 'Transportation');
    }
    const dining = [
      'Bean & Brew',
      'Sakura Sushi',
      'Luigi\'s Pizza',
      'Bean & Brew',
      'Taco Loco',
    ];
    for (final (i, d) in [3, 7, 10, 14, 18, 22, 27].indexed) {
      final payee = dining[i % dining.length];
      await card(
        d,
        payee == 'Bean & Brew' ? around(640, 120) : around(3600, 1400),
        payee,
        'Dining Out',
      );
    }
    await card(9, 1549, 'StreamFlix', 'Entertainment');
    await card(10, 1099, 'Tunewave', 'Music');
    await card(14, 299, 'CloudBox', 'Software Subscriptions');
    if (offset.isEven) {
      await card(23, around(3200, 800), 'Cinema City', 'Entertainment');
      await card(25, 1999, 'PixelPlay Store', 'Gaming');
    }
    await card(16, around(2800, 900), 'Bookworm', 'Fun Money');
    if (offset == -2) {
      await card(18, 14990, 'QuickLube Service', 'Auto Maintenance');
    }
    if (offset == -3) {
      await card(8, 4500, 'Riverside Clinic', 'Medical');
      await card(12, 4900, 'SkillPath Online', 'Education');
    }
    if (offset == -1) {
      await card(15, 6430, 'HomeFix Hardware', 'Home Maintenance');
    }
    cardSpentLastMonth = cardSpent;
  }

  // The current month: exactly demoToBeBudgeted left to assign; the rest
  // goes to the trip the household saves for.
  final tbb = await budgeting.calculateTBB(thisMonth);
  final vacation = cat('Vacation');
  await budgeting.setCategoryBudgetedAmount(
    vacation,
    _plan['Vacation']! + tbb - demoToBeBudgeted,
    thisMonth,
  );

  // Scheduled transactions and rules (Pro).
  final payees = c.read(payeeRepositoryProvider);
  final byName = {for (final p in await payees.getAllPayees()) p.name: p.id};
  final scheduled = c.read(scheduledTransactionRepositoryProvider);
  DateTime next(int dayOfMonth) {
    final d = DateTime.utc(today.year, today.month, dayOfMonth);
    return d.isAfter(today)
        ? d
        : DateTime.utc(today.year, today.month + 1, dayOfMonth);
  }

  for (final (i, s) in [
    ('Northwind Labs', null, 260000, 15),
    ('Parkside Apartments', 'Rent/Mortgage', -165000, 1),
    ('Summit Auto Loan', 'Car Payment', -35000, 5),
    ('StreamFlix', 'Entertainment', -1549, 9),
  ].indexed) {
    final (payee, category, amount, dayOfMonth) = s;
    await scheduled.createScheduledTransaction(
      ScheduledTransaction(
        id: 'demo-scheduled-$i',
        accountId: payee == 'StreamFlix' ? _visa : _checking,
        payeeId: byName[payee],
        categoryId: category == null ? null : cat(category),
        amount: amount,
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        nextDate: next(dayOfMonth),
        anchorDay: dayOfMonth,
        createdAt: created,
      ),
    );
  }

  final rules = c.read(ruleRepositoryProvider);
  for (final (i, r) in [
    ('Coffee runs', 'Bean & Brew', 'Dining Out'),
    ('Fuel', 'Fuel Stop', 'Transportation'),
    ('Groceries', 'Green Grocer', 'Groceries'),
  ].indexed) {
    final (name, keyword, category) = r;
    await rules.createRule(
      Rule(
        id: 'demo-rule-$i',
        name: name,
        priority: i,
        isActive: true,
        matchLogic: RuleMatchLogic.and,
        conditions: [
          RuleCondition(
            type: RuleConditionType.payee,
            operator: RuleConditionOperator.contains,
            value: keyword,
          ),
        ],
        actions: [
          RuleAction(type: RuleActionType.setCategory, value: cat(category)),
        ],
      ),
    );
  }
}
