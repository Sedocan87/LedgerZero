// "Undo last import" (Improvement 6): the CSV import records what it
// created; undoing deletes those rows through TransactionService, keeps
// the ones changed since, and leaves balances and the undo stack
// consistent.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/models/import_transaction.dart';
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
  late UndoService undoStack;
  late TransactionService transactions;
  late TransactionImportService importer;
  late ImportUndoService undo;
  late String checking;
  late String savings;
  late String groceries;
  final month = DateTime.utc(2025, 3);

  setUp(() async {
    t = TestDatabase();
    store = InMemoryLastImportStore();
    undoStack = UndoService();
    transactions = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: undoStack,
      unitOfWork: t.unitOfWork,
    );
    importer = TransactionImportService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      ruleMatchingService: RuleMatchingService(
        t.payees,
        t.transactions,
        t.rules,
      ),
      unitOfWork: t.unitOfWork,
      lastImportStore: store,
    );
    undo = ImportUndoService(
      transactionRepository: t.transactions,
      transactionService: transactions,
      store: store,
    );
    checking = (await t.addAccount(name: 'Checking')).id;
    savings = (await t.addAccount(name: 'Savings')).id;
    groceries = await t.categoryId('Groceries');
  });
  tearDown(() => t.close());

  ImportTransaction row(
    int amount,
    int day, {
    String? payee,
    String? accountId,
    String? transferTo,
    TransactionClearStatus? cleared,
  }) => ImportTransaction(
    date: DateTime.utc(2025, 3, day),
    amount: amount,
    payeeName: payee,
    accountId: accountId,
    transferAccountName: transferTo,
    cleared: cleared,
  );

  /// Salary, a purchase, a reconciled row and a transfer to Savings.
  Future<void> importFile() => importer.importTransactions(
    [
      row(250000, 1, payee: 'Employer'),
      row(-2345, 5, payee: 'Rewe'),
      row(-900, 6, payee: 'Kiosk', cleared: TransactionClearStatus.reconciled),
      row(-50000, 7, accountId: checking, transferTo: 'Savings'),
      row(50000, 7, accountId: savings, transferTo: 'Checking'),
    ],
    checking,
    accountIdsByName: {'checking': checking, 'savings': savings},
  );

  Future<List<Transaction>> live() => t.transactions.getAllTransactions();
  Future<int> balance(String account) async =>
      (await t.accounts.getAccountBalances())[account] ?? 0;

  test('undo deletes everything the import created: balances and To Be '
      'Budgeted are back, and the deletion is one undoable action', () async {
    final tbbBefore = await t.budgeting.calculateTBB(month);
    await importFile();
    expect(await live(), hasLength(5));
    expect(await balance(checking), 250000 - 2345 - 900 - 50000);
    expect(await balance(savings), 50000);

    final preview = (await undo.preview())!;
    expect(preview.total, 5);
    expect(preview.removable, hasLength(5));
    expect(preview.changed, 0);
    expect(preview.gone, 0);

    final done = (await undo.undo())!;
    expect(done.removable, hasLength(5));
    expect(await live(), isEmpty);
    expect(await balance(checking), 0);
    expect(await balance(savings), 0);
    expect(await t.budgeting.calculateTBB(month), tbbBefore);
    expect(store.read(), isNull, reason: 'one undo per import');
    expect(await undo.preview(), isNull);

    // Through the normal service: the deletion sits on the undo stack.
    expect(undoStack.undoCount, 1);
    await undoStack.undo();
    expect(await live(), hasLength(5));
    expect(await balance(savings), 50000);
  });

  test('rows edited, reconciled or split since the import are kept, and '
      'so is a transfer when one leg changed', () async {
    await importFile();
    final rows = await live();
    Transaction byAmount(int amount) =>
        rows.singleWhere((r) => r.amount == amount);

    // Categorised by the user.
    await transactions.bulkCategorize([byAmount(-2345).id], groceries);
    // The transfer's Savings leg gets a memo.
    await t.transactions.updateTransaction(
      byAmount(50000).copyWith(memo: 'Rainy day'),
    );
    // The salary is reconciled.
    await transactions.markAsReconciled([byAmount(250000).id]);

    final preview = (await undo.preview())!;
    expect(preview.total, 5);
    expect(preview.changed, 4, reason: 'purchase, salary, both transfer legs');
    expect(preview.gone, 0);
    // Only the row the file itself marked reconciled is untouched.
    expect(preview.removable, [byAmount(-900).id]);

    await undo.undo();
    expect((await live()).map((r) => r.amount).toList()..sort(), [
      -50000,
      -2345,
      50000,
      250000,
    ]);
    expect(await balance(checking), 250000 - 2345 - 50000);
    expect(await balance(savings), 50000);
  });

  test('a row split since the import is kept; a row deleted by hand is '
      'counted as gone', () async {
    await importFile();
    final rows = await live();
    final purchase = rows.singleWhere((r) => r.amount == -2345);
    final kiosk = rows.singleWhere((r) => r.amount == -900);
    await t.addTransaction(
      accountId: checking,
      amount: -2345,
      date: purchase.date,
      parentTransactionId: purchase.id,
      categoryId: groceries,
    );
    await transactions.deleteTransaction(kiosk.id, allowReconciledChange: true);

    final preview = (await undo.preview())!;
    expect(preview.changed, 1);
    expect(preview.gone, 1);
    expect(preview.removable, hasLength(3));

    await undo.undo();
    final left = await live();
    expect(left.map((r) => r.id), containsAll([purchase.id]));
    expect(left.where((r) => r.parentTransactionId == null), hasLength(1));
  });

  test('the record is replaced by the next import and dropped for an '
      'import too large to record', () async {
    await importFile();
    final first = store.read()!;
    expect(first.fingerprints, hasLength(5));

    await importer.importTransactions([
      row(-100, 9, payee: 'Bakery'),
    ], checking);
    final second = store.read()!;
    expect(second.fingerprints, hasLength(1));
    expect(
      first.fingerprints.keys,
      isNot(contains(second.fingerprints.keys.single)),
    );

    await ImportUndoService.record(store, [
      for (var i = 0; i <= ImportUndoService.maxRecordedRows; i++)
        Transaction(
          id: 'tx-$i',
          accountId: checking,
          date: DateTime.utc(2025, 3, 1),
          amount: -1,
        ),
    ], DateTime.utc(2025, 3, 2));
    expect(store.read(), isNull);
  });

  test('without an import there is nothing to undo', () async {
    expect(await undo.preview(), isNull);
    expect(await undo.undo(), isNull);
  });

  test('the record survives in SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final persistent = SharedPreferencesLastImportStore(prefs);
    expect(persistent.read(), isNull);

    final at = DateTime.utc(2025, 3, 2, 10, 30);
    await persistent.write(
      ImportBatch(importedAt: at, fingerprints: {'a': 'f1', 'b': 'f2'}),
    );
    final read = SharedPreferencesLastImportStore(prefs).read()!;
    expect(read.importedAt, at);
    expect(read.fingerprints, {'a': 'f1', 'b': 'f2'});

    await prefs.setString(SharedPreferencesLastImportStore.key, 'garbage');
    expect(persistent.read(), isNull);
    await persistent.clear();
    expect(prefs.getString(SharedPreferencesLastImportStore.key), isNull);
  });
}
