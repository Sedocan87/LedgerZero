// CSV rows older than an account: the account form asks for the current
// balance as the starting balance, so rows dated before the account starts
// are already in it. The import can take them out of the starting balance
// (the review's checkbox), and undoing the import gives them back.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
import 'package:ledger_zero/domain/services/budgeting_service.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/services/import/import_undo_service.dart';
import 'package:ledger_zero/services/import/transaction_import_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late InMemoryLastImportStore store;
  late TransactionImportService importer;
  late ImportUndoService undo;

  // Midday UTC: the 10th of March on the local calendar in every zone
  // from UTC-11 to UTC+11.
  final created = DateTime.utc(2025, 3, 10, 12);

  setUp(() {
    t = TestDatabase();
    store = InMemoryLastImportStore();
    importer = TransactionImportService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      ruleMatchingService: RuleMatchingService(
        t.payees,
        t.transactions,
        t.rules,
      ),
      unitOfWork: t.unitOfWork,
      accountRepository: t.accounts,
      lastImportStore: store,
    );
    undo = ImportUndoService(
      transactionRepository: t.transactions,
      transactionService: TransactionService(
        transactionRepository: t.transactions,
        payeeRepository: t.payees,
        accountRepository: t.accounts,
        undoService: UndoService(),
        unitOfWork: t.unitOfWork,
      ),
      store: store,
      accountRepository: t.accounts,
      unitOfWork: t.unitOfWork,
    );
  });
  tearDown(() => t.close());

  Future<Account> account(
    String id, {
    int startingBalance = 100000,
    DateTime? createdAt,
  }) async {
    final a = Account(
      id: id,
      name: id,
      type: AccountType.checking,
      currency: 'EUR',
      startingBalance: startingBalance,
      createdAt: createdAt,
    );
    await t.accounts.createAccount(a);
    return (await t.accounts.getAccountById(id))!;
  }

  ImportTransaction row(int amount, int month, int day, {String? accountId}) =>
      ImportTransaction(
        date: DateTime.utc(2025, month, day),
        amount: amount,
        payeeName: 'Shop',
        accountId: accountId,
      );

  Future<Account> reread(String id) async =>
      (await t.accounts.getAccountById(id))!;

  group('BudgetingService.accountStart', () {
    test('is the local creation day, or an earlier first transaction', () {
      final a = Account(
        id: 'a',
        name: 'a',
        type: AccountType.checking,
        currency: 'EUR',
        createdAt: created,
      );
      expect(BudgetingService.accountStart(a, null), DateTime.utc(2025, 3, 10));
      expect(
        BudgetingService.accountStart(a, DateTime.utc(2025, 2, 1)),
        DateTime.utc(2025, 2, 1),
      );
      expect(
        BudgetingService.accountStart(a, DateTime.utc(2025, 4, 1)),
        DateTime.utc(2025, 3, 10),
      );
      expect(
        BudgetingService.accountStart(
          const Account(
            id: 'b',
            name: 'b',
            type: AccountType.cash,
            currency: 'EUR',
          ),
          DateTime.utc(2025, 2, 1),
        ),
        isNull,
      );
    });
  });

  test('rows before the account starts are found per account; the '
      'adjustment keeps today\'s balance', () async {
    final checking = await account('Checking', createdAt: created);
    // An account with backdated history starts at its first transaction.
    final savings = await account('Savings', createdAt: created);
    await t.addTransaction(
      accountId: savings.id,
      amount: 100,
      date: DateTime.utc(2025, 2, 1),
    );
    // No starting balance: nothing can be counted twice.
    await account('Empty', startingBalance: 0, createdAt: created);
    final rows = [
      row(-2000, 3, 1),
      row(500, 3, 9),
      row(-100, 3, 10), // The start day itself: not before it.
      row(-700, 1, 20, accountId: 'Savings'),
      row(-300, 2, 15, accountId: 'Savings'),
      row(-50, 1, 5, accountId: 'Empty'),
    ];
    final accounts = await t.accounts.getAllAccounts();
    final starts = await importer.accountStarts(accounts);
    expect(starts, {
      'Checking': DateTime.utc(2025, 3, 10),
      'Savings': DateTime.utc(2025, 2, 1),
    });
    final overlaps = TransactionImportService.startingBalanceOverlaps(
      rows,
      checking.id,
      {for (final a in accounts) a.id: a},
      starts,
    );
    expect(
      {
        for (final o in overlaps)
          o.account.id: '${o.rowIndexes} ${o.net} ${o.adjustedStartingBalance}',
      },
      {'Checking': '[0, 1] -1500 101500', 'Savings': '[3] -700 100700'},
    );

    final todayChecking = checking.balance;
    final todaySavings = (await reread('Savings')).balance;
    await importer.importTransactions(
      rows,
      checking.id,
      adjustStartingBalances: true,
    );
    // Today's balance only moves by the rows from the start on.
    expect((await reread('Checking')).startingBalance, 101500);
    expect((await reread('Checking')).balance, todayChecking - 100);
    expect((await reread('Savings')).balance, todaySavings - 300);
    expect((await reread('Empty')).startingBalance, 0);
  });

  test('without the adjustment the starting balance is left alone', () async {
    final checking = await account('Checking', createdAt: created);
    await importer.importTransactions([row(-2000, 3, 1)], checking.id);
    final after = await reread('Checking');
    expect(after.startingBalance, 100000);
    expect(after.balance, 98000);
  });

  test('an account without a creation time starts at its first '
      'transaction; without one there is nothing to compare', () async {
    await account('Legacy');
    // As read from a database row without a creation time.
    const legacy = Account(
      id: 'Legacy',
      name: 'Legacy',
      type: AccountType.checking,
      currency: 'EUR',
      startingBalance: 100000,
    );
    expect(await importer.accountStarts([legacy]), isEmpty);
    await t.addTransaction(
      accountId: legacy.id,
      amount: -100,
      date: DateTime.utc(2025, 3, 1),
    );
    expect(await importer.accountStarts([legacy]), {
      'Legacy': DateTime.utc(2025, 3, 1),
    });
  });

  test('undoing the import gives the deleted rows back to the starting '
      'balance; a row changed since keeps its share', () async {
    final checking = await account('Checking', createdAt: created);
    await importer.importTransactions(
      [row(-2000, 3, 1), row(-500, 3, 2), row(-100, 3, 12)],
      checking.id,
      adjustStartingBalances: true,
    );
    expect((await reread('Checking')).startingBalance, 102500);

    // Edit the -500 row: the undo keeps it, and its adjustment with it.
    final edited = (await t.transactions.getTransactionsByAccount(
      checking.id,
    )).singleWhere((r) => r.amount == -500);
    await t.transactions.updateTransaction(edited.copyWith(memo: 'mine'));

    final preview = await undo.preview();
    expect(preview!.startingBalanceRestores, {'Checking': -2000});
    await undo.undo();
    final after = await reread('Checking');
    expect(after.startingBalance, 100500);
    expect(after.balance, 100000);
  });

  test('the rows taken out of a starting balance survive in '
      'SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final persistent = SharedPreferencesLastImportStore(prefs);
    await persistent.write(
      ImportBatch(
        importedAt: DateTime.utc(2025, 3, 2),
        fingerprints: {'a': 'f1', 'b': 'f2'},
        startingBalanceRows: {
          'acc': ['a'],
        },
      ),
    );
    expect(
      SharedPreferencesLastImportStore(prefs).read()!.startingBalanceRows,
      {
        'acc': ['a'],
      },
    );
  });
}
