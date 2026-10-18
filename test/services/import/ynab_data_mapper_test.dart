import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/constants/deterministic_id.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/budget.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/scheduled_transaction_repository.dart';
import 'package:ledger_zero/services/import/models/ynab_import_data.dart';
import 'package:ledger_zero/services/import/ynab_data_mapper.dart';
import 'package:ledger_zero/services/import/ynab_import_service.dart';

import '../../domain/services/ledger_test_helpers.dart';
import '../../helpers/test_database.dart';

/// A scheduled-transaction repository whose create always fails, to prove
/// that the import is atomic.
class _FailingScheduledTransactionRepository
    implements ScheduledTransactionRepository {
  @override
  Future<void> createScheduledTransaction(ScheduledTransaction transaction) =>
      Future.error(StateError('disk full'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

YnabDataMapper _mapper(
  TestDatabase t, {
  ScheduledTransactionRepository? scheduled,
}) => YnabDataMapper(
  accountRepo: t.accounts,
  categoryRepo: t.categories,
  payeeRepo: t.payees,
  transactionRepo: t.transactions,
  budgetRepo: t.budgets,
  scheduledTransactionRepo: scheduled ?? t.scheduledTransactions,
  unitOfWork: t.unitOfWork,
);

/// Asserts SUM(available) + TBB == SUM(on-budget account balances) for
/// [month].
Future<void> _expectInvariant(TestDatabase t, DateTime month) async {
  final categories = await t.categories.getAllCategories();
  var available = 0;
  for (final c in categories) {
    available += await t.budgeting.calculateCategoryAvailable(c.id, month);
  }
  final tbb = await t.budgeting.calculateTBB(month);
  final onBudget = {
    for (final a in await t.accounts.getAllAccounts())
      if (a.onBudget) a.id,
  };
  final balances = (await t.accounts.getAccountBalances()).entries
      .where((e) => onBudget.contains(e.key))
      .fold<int>(0, (sum, e) => sum + e.value);
  expect(available + tbb, balances, reason: 'available + TBB == balances');
}

Future<String> _accountId(TestDatabase t, String name) async =>
    (await t.accounts.getAllAccounts()).firstWhere((a) => a.name == name).id;

Future<String> _categoryIdIn(TestDatabase t, String group, String name) async {
  final groups = await t.categories.getAllCategoryGroups();
  final groupId = groups.firstWhere((g) => g.name == group).id;
  final categories = await t.categories.getAllCategories();
  return categories
      .firstWhere((c) => c.name == name && c.categoryGroupId == groupId)
      .id;
}

const _register =
    '''"Account","Flag","Date","Payee","Category Group/Category","Category Group","Category","Memo","Outflow","Inflow","Cleared"
"Checking","","01/01/2025","Starting Balance","Inflow: Ready to Assign","Inflow","Ready to Assign","","\$0.00","\$1,000.00","Reconciled"
"Visa Card","","01/01/2025","Starting Balance","Inflow: Ready to Assign","Inflow","Ready to Assign","","\$300.00","\$0.00","Cleared"
"Checking","","01/05/2025","Transfer : Visa Card","","","","Pay card","\$200.00","\$0.00","Cleared"
"Visa Card","","01/05/2025","Transfer :Checking","","","","Pay card","\$0.00","\$200.00","Uncleared"
"Visa Card","","01/10/2025","Supermarket","Everyday: Food","Everyday","Food","","\$50.00","\$0.00","Cleared"
"Checking","","01/12/2025","Landlord","Bills: Rent","Bills","Rent","","\$400.00","\$0.00","Uncleared"
''';

const _budgetCsv =
    '''"Month","Category Group/Category","Category Group","Category","Budgeted","Activity","Available"
"Jan 2025","Everyday: Food","Everyday","Food","\$100.00","-\$50.00","\$50.00"
"Jan 2025","Bills: Rent","Bills","Rent","\$400.00","-\$400.00","\$0.00"
"Jan 2025","Savings: Vacation","Savings","Vacation","\$150.00","\$0.00","\$150.00"
''';

void main() {
  late TestDatabase t;
  final january = DateTime.utc(2025, 1, 1);

  setUp(() => t = TestDatabase());
  tearDown(() => t.close());

  group('YnabImportService.transferTargetName', () {
    test('recognises YNAB transfer payees with optional spaces', () {
      expect(
        YnabImportService.transferTargetName('Transfer : Savings'),
        'Savings',
      );
      expect(
        YnabImportService.transferTargetName('Transfer:Savings'),
        'Savings',
      );
      expect(
        YnabImportService.transferTargetName('  Transfer :  My Card '),
        'My Card',
      );
      expect(YnabImportService.transferTargetName('Transferwise'), isNull);
      expect(YnabImportService.transferTargetName('Transfer :'), isNull);
      expect(YnabImportService.transferTargetName(null), isNull);
    });
  });

  group('YnabDataMapper (nYNAB CSV)', () {
    late YnabImportData data;

    setUp(() async {
      data = await YnabImportService().parseCsvExport(
        registerCsvContent: _register,
        budgetCsvContent: _budgetCsv,
      );
    });

    test('parser marks transfer rows and reads the cleared column', () {
      final transfer = data.transactions[2];
      expect(transfer.transferAccountId, 'Visa Card');
      expect(data.transactions[3].transferAccountId, 'Checking');
      expect(data.transactions[0].transferAccountId, isNull);
      expect(data.transactions[0].reconciled, isTrue);
      expect(data.transactions[1].cleared, isTrue);
      expect(data.transactions[3].cleared, isFalse);
    });

    test('starting balances, transfer, spending and budgets keep the '
        'budget invariant', () async {
      await _mapper(t).importData(data, currency: 'USD');

      final checking = await _accountId(t, 'Checking');
      final card = await _accountId(t, 'Visa Card');

      // Starting balances live in the "Starting Balance" rows only.
      for (final a in await t.accounts.getAllAccounts()) {
        expect(a.startingBalance, 0, reason: a.name);
      }
      expect(
        (await t.accounts.getAllAccounts())
            .firstWhere((a) => a.id == card)
            .type,
        AccountType.credit,
      );

      final balances = await t.accounts.getAccountBalances();
      expect(balances[checking], 100000 - 20000 - 40000);
      expect(balances[card], -30000 + 20000 - 5000);

      // TBB = +1000 - 300 (starting balance rows) - 650 budgeted (the
      // Vacation fund exists only in Budget.csv and is created too).
      expect(await t.budgeting.calculateTBB(january), 5000);
      expect(data.categoriesOnlyInBudget, 1);
      final vacation = await _categoryIdIn(t, 'Savings', 'Vacation');
      expect(
        await t.budgeting.calculateCategoryAvailable(vacation, january),
        15000,
      );

      final food = await _categoryIdIn(t, 'Everyday', 'Food');
      final rent = await _categoryIdIn(t, 'Bills', 'Rent');
      expect(await t.budgeting.calculateCategoryAvailable(food, january), 5000);
      expect(await t.budgeting.calculateCategoryAvailable(rent, january), 0);
      await _expectInvariant(t, january);

      // Transfer legs are linked both ways and carry no category / payee.
      final rows = await t.transactions.getAllTransactions();
      final legs = rows.where((r) => r.transferAccountId != null).toList();
      expect(legs, hasLength(2));
      final out = legs.firstWhere((l) => l.accountId == checking);
      final into = legs.firstWhere((l) => l.accountId == card);
      expect(out.amount, -20000);
      expect(into.amount, 20000);
      expect(out.transferAccountId, card);
      expect(into.transferAccountId, checking);
      expect(out.transferTransactionId, into.id);
      expect(into.transferTransactionId, out.id);
      for (final leg in legs) {
        expect(leg.categoryId, isNull);
        expect(leg.payeeId, isNull);
        expect(leg.memo, 'Pay card');
      }
      expect(out.cleared, TransactionClearStatus.cleared);
      expect(into.cleared, TransactionClearStatus.uncleared);

      // Starting balance rows are uncategorised.
      final payees = await t.payees.getAllPayees();
      final startingBalance = payees.firstWhere(
        (p) => p.name == 'Starting Balance',
      );
      final startRows = rows.where((r) => r.payeeId == startingBalance.id);
      expect(startRows.map((r) => r.amount), unorderedEquals([100000, -30000]));
      expect(startRows.every((r) => r.categoryId == null), isTrue);

      // No "Transfer : X" payee and no "Ready to Assign" category/group.
      expect(
        payees.where((p) => p.name.toLowerCase().startsWith('transfer')),
        isEmpty,
      );
      final categories = await t.categories.getAllCategories();
      expect(categories.where((c) => c.name == 'Ready to Assign'), isEmpty);
      final groups = await t.categories.getAllCategoryGroups();
      expect(groups.where((g) => g.name == 'Inflow'), isEmpty);
    });

    test('budget rows use the deterministic id; existing rows are updated '
        'by category and month', () async {
      // Categories must exist before the import to pre-create a budget.
      await _mapper(t).importData(
        YnabImportData(
          accounts: const [],
          categoryGroups: data.categoryGroups,
          categories: data.categories,
          transactions: const [],
          budgetEntries: const [],
          source: 'CSV',
          importedAt: DateTime.now().toUtc(),
        ),
        currency: 'USD',
      );
      final food = await _categoryIdIn(t, 'Everyday', 'Food');
      final rent = await _categoryIdIn(t, 'Bills', 'Rent');
      await t.budgets.createBudget(
        Budget(
          id: 'legacy-food',
          categoryId: food,
          month: '2025-01',
          budgeted: 1,
        ),
      );

      await _mapper(t).importData(data, currency: 'USD');

      final budgets = await t.budgets.getBudgetsForMonth('2025-01');
      final foodRows = budgets.where((b) => b.categoryId == food).toList();
      expect(foodRows, hasLength(1));
      expect(foodRows.single.id, 'legacy-food');
      expect(foodRows.single.budgeted, 10000);
      final rentRow = budgets.singleWhere((b) => b.categoryId == rent);
      expect(rentRow.id, DeterministicId.budgetForKey(rent, '2025-01'));
      expect(rentRow.id, DeterministicId.budget(rent, january));
      expect(rentRow.budgeted, 40000);
    });

    test('the import is atomic', () async {
      final accountsBefore = (await t.accounts.getAllAccounts()).length;
      final categoriesBefore = (await t.categories.getAllCategories()).length;
      final failing = YnabImportData(
        accounts: data.accounts,
        categoryGroups: data.categoryGroups,
        categories: data.categories,
        transactions: data.transactions,
        scheduledTransactions: [
          YnabScheduledTransaction(
            id: 's1',
            accountId: 'Checking',
            payeeName: 'Gym',
            amount: -3000,
            frequency: RecurrenceFrequency.monthly,
            nextDate: DateTime.utc(2025, 2, 1),
          ),
        ],
        budgetEntries: data.budgetEntries,
        source: 'CSV',
        importedAt: DateTime.now().toUtc(),
      );

      await expectLater(
        _mapper(
          t,
          scheduled: _FailingScheduledTransactionRepository(),
        ).importData(failing, currency: 'USD'),
        throwsA(isA<StateError>()),
      );

      expect(await t.accounts.getAllAccounts(), hasLength(accountsBefore));
      expect(
        await t.categories.getAllCategories(),
        hasLength(categoriesBefore),
      );
      expect(await t.transactions.getAllTransactions(), isEmpty);
      expect(await t.payees.getAllPayees(), isEmpty);
      expect(await t.budgets.getAllBudgets(), isEmpty);
    });
  });

  group('YnabDataMapper (YNAB4 data)', () {
    YnabTransaction tx(
      String id,
      String account,
      int amount, {
      String? payee,
      String? transferTo,
      String? group,
      String? category,
      List<YnabSplitItem> splits = const [],
      DateTime? date,
    }) => YnabTransaction(
      id: id,
      accountId: account,
      date: date ?? DateTime.utc(2025, 1, 15),
      payeeName: payee,
      categoryGroupName: group,
      categoryName: category,
      amount: amount,
      transferAccountId: transferTo,
      splits: splits,
    );

    YnabImportData ynab4(List<YnabTransaction> transactions) => YnabImportData(
      accounts: [
        YnabAccount(id: 'a', name: 'Checking', type: AccountType.checking),
        YnabAccount(id: 'b', name: 'Savings', type: AccountType.savings),
        // A closed account (imported as closed).
        YnabAccount(
          id: 'c',
          name: 'Old Account',
          type: AccountType.checking,
          isClosed: true,
        ),
      ],
      categoryGroups: [YnabCategoryGroup(id: 'g', name: 'Everyday')],
      categories: [
        YnabCategory(id: 'food', groupId: 'g', name: 'Food'),
        YnabCategory(id: 'fun', groupId: 'g', name: 'Fun'),
      ],
      transactions: transactions,
      budgetEntries: [
        YnabBudgetEntry(
          categoryName: 'Food',
          categoryGroupName: 'Everyday',
          month: DateTime(2025, 1, 1),
          budgeted: 30000,
        ),
      ],
      source: 'YNAB4',
      importedAt: DateTime.now().toUtc(),
    );

    test(
      'pairs transfers one-to-one, imports orphan legs as normal rows',
      () async {
        await _mapper(t).importData(
          ynab4([
            tx('s1', 'a', 100000, payee: 'Starting Balance'),
            // Two identical transfers on the same day.
            tx('t1', 'a', -2000, payee: 'Transfer : Savings', transferTo: 'b'),
            tx('t2', 'a', -2000, payee: 'Transfer : Savings', transferTo: 'b'),
            tx('t3', 'b', 2000, payee: 'Transfer : Checking', transferTo: 'a'),
            tx('t4', 'b', 2000, payee: 'Transfer : Checking', transferTo: 'a'),
            // Different day: no partner.
            tx(
              't5',
              'b',
              700,
              payee: 'Transfer : Checking',
              transferTo: 'a',
              date: DateTime.utc(2025, 1, 16),
            ),
            // Its other leg is missing from the closed account.
            tx(
              't6',
              'a',
              -5000,
              payee: 'Transfer : Old Account',
              transferTo: 'c',
            ),
            // Categorised "transfer" (YNAB: to a tracking account).
            tx(
              't7',
              'a',
              -1500,
              transferTo: 'b',
              group: 'Everyday',
              category: 'Fun',
            ),
            tx('t8', 'b', 1500, transferTo: 'a'),
          ]),
          currency: 'USD',
        );

        final checking = await _accountId(t, 'Checking');
        final savings = await _accountId(t, 'Savings');
        final rows = await t.transactions.getAllTransactions();

        final legs = rows.where((r) => r.transferAccountId != null).toList();
        expect(legs, hasLength(6));
        for (final leg in legs) {
          final other = rows.firstWhere(
            (r) => r.id == leg.transferTransactionId,
          );
          expect(other.transferTransactionId, leg.id);
          expect(other.transferAccountId, leg.accountId);
          expect(leg.transferAccountId, other.accountId);
          expect(other.amount, -leg.amount);
          expect(leg.categoryId, isNull);
          expect(leg.payeeId, isNull);
        }

        // Orphans: no link, uncategorised, memo keeps the transfer payee.
        final orphan = rows.singleWhere((r) => r.amount == 700);
        expect(orphan.transferAccountId, isNull);
        expect(orphan.categoryId, isNull);
        expect(orphan.payeeId, isNull);
        expect(orphan.memo, 'Transfer : Checking');
        final toClosed = rows.singleWhere((r) => r.amount == -5000);
        expect(toClosed.transferAccountId, isNull);
        expect(toClosed.categoryId, isNull);
        expect(toClosed.memo, 'Transfer : Old Account');

        // A transfer categorised on one side is linked too; between two
        // budget accounts the category is dropped (the budget ignores it).
        final t7 = rows.singleWhere((r) => r.amount == -1500);
        expect(t7.transferAccountId, savings);
        expect(t7.categoryId, isNull);
        final t8 = rows.singleWhere((r) => r.amount == 1500);
        expect(t8.transferTransactionId, t7.id);

        final payees = await t.payees.getAllPayees();
        expect(payees.map((p) => p.name), ['Starting Balance']);

        final balances = await t.accounts.getAccountBalances();
        expect(balances[checking], 100000 - 4000 - 5000 - 1500);
        expect(balances[savings], 4000 + 700 + 1500);
        // +1000 start, +7 orphan, -50 orphan, -300 budgeted; the linked
        // t7/t8 transfer moves nothing in or out of the budget.
        expect(
          await t.budgeting.calculateTBB(january),
          100000 + 700 - 5000 - 30000,
        );
        await _expectInvariant(t, january);
      },
    );

    test('split children always add up to the parent', () async {
      await _mapper(t).importData(
        ynab4([
          tx('s1', 'a', 50000, payee: 'Starting Balance'),
          tx(
            'x1',
            'a',
            -10000,
            payee: 'Market',
            splits: [
              YnabSplitItem(
                categoryGroupName: 'Everyday',
                categoryName: 'Food',
                amount: -6000,
              ),
              YnabSplitItem(
                categoryGroupName: 'Everyday',
                categoryName: 'Fun',
                amount: -3000,
                memo: 'toy',
              ),
            ],
          ),
        ]),
        currency: 'USD',
      );

      final rows = await t.transactions.getAllTransactions();
      final parent = rows.singleWhere((r) => r.amount == -10000);
      expect(parent.categoryId, isNull);
      final children = rows
          .where((r) => r.parentTransactionId == parent.id)
          .toList();
      expect(children, hasLength(3));
      expect(children.fold<int>(0, (s, c) => s + c.amount), -10000);
      final remainder = children.singleWhere((c) => c.categoryId == null);
      expect(remainder.amount, -1000);
      expect(remainder.payeeId, parent.payeeId);

      final checking = await _accountId(t, 'Checking');
      expect((await t.accounts.getAccountBalances())[checking], 40000);
      // +500 start, -10 remainder, -300 budgeted.
      expect(await t.budgeting.calculateTBB(january), 50000 - 1000 - 30000);
      final food = await _categoryIdIn(t, 'Everyday', 'Food');
      expect(
        await t.budgeting.calculateCategoryAvailable(food, january),
        30000 - 6000,
      );
      await _expectInvariant(t, january);
    });
  });

  group('YnabDataMapper (nYNAB CSV splits)', () {
    const register =
        '''"Account","Flag","Date","Payee","Category Group/Category","Category Group","Category","Memo","Outflow","Inflow","Cleared"
"Checking","","01/01/2025","Starting Balance","Inflow: Ready to Assign","Inflow","Ready to Assign","","\$0.00","\$1,000.00","Reconciled"
"Checking","","01/15/2025","Market","Everyday: Food","Everyday","Food","Split (1/3) Groceries","\$60.00","\$0.00","Cleared"
"Checking","","01/15/2025","Market","Everyday: Fun","Everyday","Fun","Split (2/3) ","\$30.00","\$0.00","Cleared"
"Checking","","01/15/2025","Transfer : Savings","","","","Split (3/3) Cash back","\$20.00","\$0.00","Cleared"
"Savings","","01/15/2025","Transfer : Checking","","","","Cash back","\$0.00","\$20.00","Cleared"
''';

    const budget =
        '''"Month","Category Group/Category","Category Group","Category","Budgeted","Activity","Available"
"Jan 2025","Everyday: Food","Everyday","Food","\$100.00","-\$60.00","\$40.00"
''';

    test('split lines become a parent plus categorised children', () async {
      final parsed = await YnabImportService().parseCsvExport(
        registerCsvContent: register,
        budgetCsvContent: budget,
      );
      // Savings has only a transfer leg, so it is taken for a tracking
      // account; the user keeps it on budget in the preview.
      expect(parsed.accounts.singleWhere((a) => a.name == 'Savings').onBudget,
          isFalse);
      final data = parsed.copyWith(
        accounts: [for (final a in parsed.accounts) a.copyWith(onBudget: true)],
      );
      await _mapper(t).importData(data, currency: 'USD');

      final checking = await _accountId(t, 'Checking');
      final savings = await _accountId(t, 'Savings');
      final food = await _categoryIdIn(t, 'Everyday', 'Food');
      final fun = await _categoryIdIn(t, 'Everyday', 'Fun');
      final rows = await t.transactions.getAllTransactions();
      final market = (await t.payees.getAllPayees()).singleWhere(
        (p) => p.name == 'Market',
      );

      final parent = rows.singleWhere(
        (r) => r.accountId == checking && r.amount == -11000,
      );
      expect(parent.categoryId, isNull);
      expect(parent.parentTransactionId, isNull);
      expect(parent.transferAccountId, isNull);
      expect(parent.payeeId, market.id);
      expect(parent.memo, isNull);
      expect(parent.cleared, TransactionClearStatus.cleared);

      final children = rows
          .where((r) => r.parentTransactionId == parent.id)
          .toList();
      expect(children, hasLength(3));
      expect(children.fold<int>(0, (s, c) => s + c.amount), parent.amount);
      final byAmount = {for (final c in children) c.amount: c};
      expect(byAmount[-6000]!.categoryId, food);
      expect(byAmount[-6000]!.memo, 'Groceries');
      expect(byAmount[-3000]!.categoryId, fun);
      expect(byAmount[-3000]!.memo, isNull);
      // The transfer line: uncategorised child, memo names the transfer.
      final transferLine = byAmount[-2000]!;
      expect(transferLine.categoryId, isNull);
      expect(transferLine.transferAccountId, isNull);
      expect(transferLine.memo, 'Transfer : Savings - Cash back');
      for (final c in children) {
        expect(c.accountId, checking);
        expect(c.payeeId, market.id);
        expect(c.memo ?? '', isNot(contains('Split (')));
      }

      // Its counterpart is a normal, unlinked row.
      final savingsRow = rows.singleWhere(
        (r) => r.accountId == savings && r.amount == 2000,
      );
      expect(savingsRow.transferAccountId, isNull);
      expect(savingsRow.transferTransactionId, isNull);
      expect(savingsRow.categoryId, isNull);
      expect(savingsRow.memo, 'Transfer : Checking - Cash back');

      final balances = await t.accounts.getAccountBalances();
      expect(balances[checking], 100000 - 11000);
      expect(balances[savings], 2000);
      expect(
        await t.budgeting.calculateCategoryAvailable(food, january),
        10000 - 6000,
      );
      // +1000 start, -20 transfer line, +20 counterpart, -100 budgeted.
      expect(await t.budgeting.calculateTBB(january), 100000 - 10000);
      await _expectInvariant(t, january);
    });
  });

  group('YnabDataMapper (closed accounts and schedules)', () {
    YnabImportData data({
      List<YnabTransaction> transactions = const [],
      List<YnabScheduledTransaction> scheduled = const [],
    }) => YnabImportData(
      accounts: [
        YnabAccount(id: 'a', name: 'Checking', type: AccountType.checking),
        YnabAccount(
          id: 'c',
          name: 'Old Savings',
          type: AccountType.savings,
          isClosed: true,
        ),
      ],
      categoryGroups: [YnabCategoryGroup(id: 'g', name: 'Everyday')],
      categories: [YnabCategory(id: 'food', groupId: 'g', name: 'Food')],
      transactions: transactions,
      scheduledTransactions: scheduled,
      budgetEntries: const [],
      source: 'YNAB4',
      importedAt: DateTime.now().toUtc(),
    );

    test('closed accounts are imported as closed with their transactions '
        'and transfer counterparts', () async {
      final day = DateTime.utc(2025, 1, 10);
      await _mapper(t).importData(
        data(
          transactions: [
            YnabTransaction(
              id: 's1',
              accountId: 'a',
              date: day,
              payeeName: 'Starting Balance',
              amount: 100000,
            ),
            YnabTransaction(
              id: 's2',
              accountId: 'c',
              date: day,
              payeeName: 'Starting Balance',
              amount: 5000,
            ),
            YnabTransaction(
              id: 't1',
              accountId: 'c',
              date: DateTime.utc(2025, 1, 20),
              payeeName: 'Transfer : Checking',
              amount: -5000,
              transferAccountId: 'a',
            ),
            YnabTransaction(
              id: 't2',
              accountId: 'a',
              date: DateTime.utc(2025, 1, 20),
              payeeName: 'Transfer : Old Savings',
              amount: 5000,
              transferAccountId: 'c',
            ),
          ],
        ),
        currency: 'USD',
      );

      final accounts = await t.accounts.getAllAccounts();
      final old = accounts.singleWhere((a) => a.name == 'Old Savings');
      final checking = accounts.singleWhere((a) => a.name == 'Checking');
      expect(old.isClosed, isTrue);
      expect(old.type, AccountType.savings);
      expect(checking.isClosed, isFalse);

      final rows = await t.transactions.getAllTransactions();
      expect(rows.where((r) => r.accountId == old.id), hasLength(2));
      final legOld = rows.singleWhere(
        (r) => r.accountId == old.id && r.amount == -5000,
      );
      final legChecking = rows.singleWhere(
        (r) => r.accountId == checking.id && r.amount == 5000,
      );
      expect(legOld.transferTransactionId, legChecking.id);
      expect(legChecking.transferTransactionId, legOld.id);
      expect(legOld.transferAccountId, checking.id);
      expect(legChecking.transferAccountId, old.id);

      final balances = await t.accounts.getAccountBalances();
      expect(balances[old.id], 0);
      expect(balances[checking.id], 105000);
      await _expectInvariant(t, january);
    });

    test('scheduled transfers become normal schedules whose memo names the '
        'transfer', () async {
      await _mapper(t).importData(
        data(
          scheduled: [
            YnabScheduledTransaction(
              id: 'st',
              accountId: 'a',
              payeeName: 'Transfer : Old Savings',
              memo: 'Saving',
              amount: -50000,
              frequency: RecurrenceFrequency.weekly,
              interval: 2,
              nextDate: DateTime.utc(2025, 2, 1),
              transferAccountId: 'c',
            ),
            YnabScheduledTransaction(
              id: 'gym',
              accountId: 'a',
              payeeName: 'Gym',
              categoryGroupName: 'Everyday',
              categoryName: 'Food',
              memo: 'Membership',
              amount: -3000,
              frequency: RecurrenceFrequency.monthly,
              occurrenceCount: 1,
              nextDate: DateTime.utc(2025, 2, 3),
            ),
          ],
        ),
        currency: 'USD',
      );

      final checking = await _accountId(t, 'Checking');
      final schedules = await t.scheduledTransactions
          .getAllScheduledTransactions();
      expect(schedules, hasLength(2));

      final transfer = schedules.singleWhere((s) => s.amount == -50000);
      expect(transfer.accountId, checking);
      expect(transfer.payeeId, isNull);
      expect(transfer.categoryId, isNull);
      expect(transfer.memo, 'Transfer : Old Savings - Saving');
      expect(transfer.frequency, RecurrenceFrequency.weekly);
      expect(transfer.interval, 2);
      expect(transfer.nextDate, DateTime.utc(2025, 2, 1));

      final gym = schedules.singleWhere((s) => s.amount == -3000);
      final gymPayee = (await t.payees.getAllPayees()).singleWhere(
        (p) => p.name == 'Gym',
      );
      expect(gym.payeeId, gymPayee.id);
      expect(gym.categoryId, await _categoryIdIn(t, 'Everyday', 'Food'));
      expect(gym.memo, 'Membership');
      expect(gym.occurrenceCount, 1);

      // No "Transfer : X" payee is created.
      expect((await t.payees.getAllPayees()).map((p) => p.name), ['Gym']);
    });
  });

  group('YnabDataMapper (currency, hidden categories, tracking accounts)', () {
    YnabImportData data({
      required List<YnabAccount> accounts,
      required List<YnabTransaction> transactions,
      List<YnabCategoryGroup> groups = const [],
      List<YnabCategory> categories = const [],
    }) => YnabImportData(
      accounts: accounts,
      categoryGroups: groups,
      categories: categories,
      transactions: transactions,
      budgetEntries: const [],
      source: 'YNAB4',
      importedAt: DateTime.now().toUtc(),
    );

    test('new accounts get the chosen currency', () async {
      await _mapper(t).importData(
        data(
          accounts: [
            YnabAccount(id: 'a', name: 'Girokonto', type: AccountType.checking),
          ],
          transactions: const [],
        ),
        currency: 'EUR',
      );
      final account = (await t.accounts.getAllAccounts()).single;
      expect(account.currency, 'EUR');
    });

    test('hidden groups and categories are imported hidden, with their '
        'transactions', () async {
      await _mapper(t).importData(
        data(
          accounts: [
            YnabAccount(id: 'a', name: 'Checking', type: AccountType.checking),
          ],
          groups: [
            YnabCategoryGroup(id: 'g1', name: 'Everyday'),
            YnabCategoryGroup(id: 'g2', name: 'Old Stuff', isHidden: true),
          ],
          categories: [
            YnabCategory(
              id: 'c1',
              groupId: 'g1',
              name: 'Snacks',
              isHidden: true,
            ),
            YnabCategory(id: 'c2', groupId: 'g2', name: 'Hobby'),
          ],
          transactions: [
            YnabTransaction(
              id: 't1',
              accountId: 'a',
              date: DateTime.utc(2025, 1, 10),
              amount: -1000,
              categoryGroupName: 'Old Stuff',
              categoryName: 'Hobby',
            ),
          ],
        ),
        currency: 'USD',
      );
      final hobby = await _categoryIdIn(t, 'Old Stuff', 'Hobby');
      final snacks = await _categoryIdIn(t, 'Everyday', 'Snacks');
      final all = {
        for (final c in await t.categories.getAllCategories()) c.id: c,
      };
      expect(all[hobby]!.isHidden, isTrue);
      expect(all[snacks]!.isHidden, isTrue);
      expect(
        (await t.transactions.getAllTransactions()).single.categoryId,
        hobby,
      );
    });

    test('tracking accounts are imported off budget; a categorised transfer '
        'to one keeps the category on the budget leg (I6)', () async {
      final summary = await _mapper(t).importData(
        data(
          accounts: [
            YnabAccount(id: 'a', name: 'Checking', type: AccountType.checking),
            YnabAccount(
              id: 'h',
              name: 'House',
              type: AccountType.checking,
              onBudget: false,
            ),
            YnabAccount(
              id: 'r',
              name: 'Retirement',
              type: AccountType.savings,
              onBudget: false,
            ),
          ],
          groups: [YnabCategoryGroup(id: 'g', name: 'Everyday')],
          categories: [YnabCategory(id: 'c', groupId: 'g', name: 'Home')],
          transactions: [
            YnabTransaction(
              id: 's',
              accountId: 'a',
              date: DateTime.utc(2025, 1, 1),
              amount: 100000,
              payeeName: 'Starting Balance',
            ),
            YnabTransaction(
              id: 'hs',
              accountId: 'h',
              date: DateTime.utc(2025, 1, 1),
              amount: 30000000,
              payeeName: 'Starting Balance',
            ),
            // Categorised outflow to a tracking account (YNAB style).
            YnabTransaction(
              id: 't1',
              accountId: 'a',
              date: DateTime.utc(2025, 1, 5),
              amount: -20000,
              transferAccountId: 'h',
              payeeName: 'Transfer : House',
              categoryGroupName: 'Everyday',
              categoryName: 'Home',
            ),
            YnabTransaction(
              id: 't1b',
              accountId: 'h',
              date: DateTime.utc(2025, 1, 5),
              amount: 20000,
              transferAccountId: 'a',
            ),
            // Money coming into the budget from a tracking account.
            YnabTransaction(
              id: 't2',
              accountId: 'a',
              date: DateTime.utc(2025, 1, 6),
              amount: 5000,
              transferAccountId: 'r',
              payeeName: 'Transfer : Retirement',
            ),
            YnabTransaction(
              id: 't2b',
              accountId: 'r',
              date: DateTime.utc(2025, 1, 6),
              amount: -5000,
              transferAccountId: 'a',
            ),
            // A categorised row inside the tracking account: no category.
            YnabTransaction(
              id: 'hi',
              accountId: 'h',
              date: DateTime.utc(2025, 1, 7),
              amount: 1000,
              payeeName: 'Interest',
              categoryGroupName: 'Everyday',
              categoryName: 'Home',
            ),
          ],
        ),
        currency: 'USD',
      );

      expect(summary.trackingAccounts, 2);
      expect(summary.accounts, 3);
      expect(summary.transactions, 7);

      final accounts = {
        for (final a in await t.accounts.getAllAccounts()) a.name: a,
      };
      expect(
        accounts.keys,
        unorderedEquals(['Checking', 'House', 'Retirement']),
      );
      expect(accounts['Checking']!.onBudget, isTrue);
      expect(accounts['House']!.onBudget, isFalse);
      expect(accounts['Retirement']!.onBudget, isFalse);

      final rows = await t.transactions.getAllTransactions();
      expect(rows, hasLength(7));
      final home = await _categoryIdIn(t, 'Everyday', 'Home');
      final out = rows.singleWhere((r) => r.amount == -20000);
      final into = rows.singleWhere((r) => r.amount == 20000);
      expect(out.transferAccountId, accounts['House']!.id);
      expect(out.transferTransactionId, into.id);
      expect(into.transferTransactionId, out.id);
      expect(out.categoryId, home, reason: 'budget-side leg keeps it');
      expect(into.categoryId, isNull);
      final inflow = rows.singleWhere((r) => r.amount == 5000);
      expect(inflow.transferAccountId, accounts['Retirement']!.id);
      expect(inflow.categoryId, isNull);
      final interest = rows.singleWhere((r) => r.amount == 1000);
      expect(interest.categoryId, isNull);

      final balances = await t.accounts.getAccountBalances();
      expect(balances[accounts['Checking']!.id], 100000 - 20000 + 5000);
      expect(balances[accounts['House']!.id], 30000000 + 20000 + 1000);
      expect(balances[accounts['Retirement']!.id], -5000);
      // Starting balance + the inflow from Retirement; the outflow to
      // House left the Home category, not To Be Budgeted.
      expect(await t.budgeting.calculateTBB(january), 100000 + 5000);
      expect(
        await t.budgeting.calculateCategoryAvailable(home, january),
        -20000,
      );
      await _expectInvariant(t, january);
      await expectLedgerInvariant(t, january);
    });
  });
}
