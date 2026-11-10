// A closed account takes no new rows through TransactionService.save
// (fourth audit, ledger F3); what is already there stays editable.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late UndoService undo;
  late TransactionService service;
  final day = DateTime.utc(2024, 3, 15);

  setUp(() async {
    t = TestDatabase();
    undo = UndoService();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: undo,
      unitOfWork: t.unitOfWork,
    );
    await t.addAccount(id: 'open', name: 'New Checking');
    await t.addAccount(id: 'old', name: 'Old Checking');
    await t.addAccount(id: 'other', name: 'Savings');
  });

  tearDown(() => t.close());

  Future<void> close(String id) async {
    final account = (await t.accounts.getAccountById(id))!;
    await t.accounts.updateAccount(account.copyWith(isClosed: true));
  }

  Future<List<Transaction>> live() => t.transactions.getAllTransactions();

  final rejectsClosed = throwsA(
    isA<ValidationException>().having(
      (e) => e.code,
      'code',
      TransactionValidationError.closedAccount,
    ),
  );

  test('a new transaction in a closed account is rejected', () async {
    await close('old');
    await expectLater(
      service.save(TransactionInput(accountId: 'old', date: day, amount: -500)),
      rejectsClosed,
    );
    expect(await live(), isEmpty);
    expect(undo.canUndo, isFalse);
  });

  test('a new transfer into or out of a closed account is rejected', () async {
    await close('old');
    for (final (from, to) in [('open', 'old'), ('old', 'open')]) {
      await expectLater(
        service.save(
          TransactionInput(
            accountId: from,
            date: day,
            amount: -500,
            transferAccountId: to,
          ),
        ),
        rejectsClosed,
      );
    }
    expect(await live(), isEmpty);
  });

  test('rows already in the account can still be edited, deleted and '
      'restored', () async {
    final id = (await service.save(
      TransactionInput(accountId: 'old', date: day, amount: -500),
    )).id;
    await close('old');

    await service.save(
      TransactionInput(
        id: id,
        accountId: 'old',
        date: day,
        amount: -750,
        memo: 'corrected',
      ),
    );
    final edited = (await live()).single;
    expect(edited.amount, -750);
    expect(edited.memo, 'corrected');

    final deletion = await service.deleteTransaction(id);
    expect(await live(), isEmpty);
    await undo.undo(deletion);
    expect((await live()).single.amount, -750);
  });

  test('a transfer with a leg in the closed account can still be edited '
      'from either leg', () async {
    final outId = (await service.save(
      TransactionInput(
        accountId: 'open',
        date: day,
        amount: -500,
        transferAccountId: 'old',
      ),
    )).id;
    await close('old');

    await service.save(
      TransactionInput(
        id: outId,
        accountId: 'open',
        date: day,
        amount: -600,
        transferAccountId: 'old',
      ),
    );
    final inId = (await live()).firstWhere((r) => r.id != outId).id;
    await service.save(
      TransactionInput(
        id: inId,
        accountId: 'old',
        date: day,
        amount: 700,
        transferAccountId: 'open',
      ),
    );
    final rows = {for (final r in await live()) r.id: r};
    expect(rows[outId]!.amount, -700);
    expect(rows[inId]!.amount, 700);
    expect(rows[inId]!.accountId, 'old');
  });

  test('an existing row cannot move into a closed account, as itself or as '
      'the other leg of a transfer', () async {
    final id = (await service.save(
      TransactionInput(accountId: 'open', date: day, amount: -500),
    )).id;
    final transferId = (await service.save(
      TransactionInput(
        accountId: 'open',
        date: day,
        amount: -900,
        transferAccountId: 'other',
      ),
    )).id;
    await close('old');

    // Moved to the closed account.
    await expectLater(
      service.save(
        TransactionInput(id: id, accountId: 'old', date: day, amount: -500),
      ),
      rejectsClosed,
    );
    // Turned into a transfer whose new leg would be in it.
    await expectLater(
      service.save(
        TransactionInput(
          id: id,
          accountId: 'open',
          date: day,
          amount: -500,
          transferAccountId: 'old',
        ),
      ),
      rejectsClosed,
    );
    // The other leg of a transfer moved into it.
    await expectLater(
      service.save(
        TransactionInput(
          id: transferId,
          accountId: 'open',
          date: day,
          amount: -900,
          transferAccountId: 'old',
        ),
      ),
      rejectsClosed,
    );
    final rows = await live();
    expect(rows, hasLength(3));
    expect(rows.map((r) => r.accountId), isNot(contains('old')));
  });

  test('moving a row out of a closed account works', () async {
    final id = (await service.save(
      TransactionInput(accountId: 'old', date: day, amount: -500),
    )).id;
    await close('old');
    await service.save(
      TransactionInput(id: id, accountId: 'open', date: day, amount: -500),
    );
    expect((await live()).single.accountId, 'open');
  });

  test('reconciling a closed account still adds its adjustment (the '
      'reconciliation does not go through save)', () async {
    await close('old');
    final result = await service.reconcile(
      accountId: 'old',
      statementDate: day,
      statementBalance: 1234,
      adjustmentMemo: 'Adjustment',
      clearedBalanceUpTo: (id, upTo) =>
          t.accounts.getClearedBalance(id, upTo: upTo),
    );
    expect(result.adjustmentId, isNotNull);
    expect((await live()).single.amount, 1234);
  });
}
