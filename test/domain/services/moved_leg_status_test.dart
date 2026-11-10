// A reconciled status stays with the account whose reconciliation
// included the row (fourth audit, ledger improvement 6): a leg moved to
// another account starts uncleared there.
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/presentation/providers/formatter_provider.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/presentation/screens/transactions/form/transaction_form_controller.dart';

import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late TransactionService service;
  final day = DateTime.utc(2024, 3, 15);
  const reconciled = TransactionClearStatus.reconciled;
  const uncleared = TransactionClearStatus.uncleared;

  setUp(() async {
    t = TestDatabase();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
    );
    for (final id in ['checking', 'savings', 'cash']) {
      await t.addAccount(id: id, name: id);
    }
  });

  tearDown(() => t.close());

  Future<Transaction> row(String id) async =>
      (await t.transactions.getTransactionById(id))!;

  Future<(String, String)> reconciledTransfer() async {
    final out = await service.save(
      TransactionInput(
        accountId: 'checking',
        date: day,
        amount: -500,
        transferAccountId: 'savings',
        cleared: reconciled,
        counterpartCleared: reconciled,
      ),
    );
    return (out.id, (await row(out.id)).transferTransactionId!);
  }

  test('the To leg moved to another account starts uncleared there, even '
      'when the input carries its old status (as the form does)', () async {
    final (outId, _) = await reconciledTransfer();
    await service.save(
      TransactionInput(
        id: outId,
        accountId: 'checking',
        date: day,
        amount: -500,
        transferAccountId: 'cash',
        cleared: reconciled,
        counterpartCleared: reconciled,
      ),
      allowReconciledChange: true,
    );
    final out = await row(outId);
    expect(out.cleared, reconciled);
    final moved = await row(out.transferTransactionId!);
    expect(moved.accountId, 'cash');
    expect(moved.cleared, uncleared);
  });

  test('the edited row moved to another account starts uncleared, with its '
      'split lines', () async {
    final created = await service.save(
      TransactionInput(
        accountId: 'checking',
        date: day,
        amount: -500,
        cleared: reconciled,
        splits: const [
          SplitLineInput(amount: -200),
          SplitLineInput(amount: -300),
        ],
      ),
    );
    final lines = await t.transactions.getSplitTransactions(created.id);
    await service.save(
      TransactionInput(
        id: created.id,
        accountId: 'cash',
        date: day,
        amount: -500,
        cleared: reconciled,
        splits: [
          for (final l in lines) SplitLineInput(id: l.id, amount: l.amount),
        ],
      ),
      allowReconciledChange: true,
    );
    expect((await row(created.id)).cleared, uncleared);
    for (final l in await t.transactions.getSplitTransactions(created.id)) {
      expect(l.cleared, uncleared);
    }
  });

  test('a leg that stays keeps its reconciled status', () async {
    final (outId, inId) = await reconciledTransfer();
    await service.save(
      TransactionInput(
        id: outId,
        accountId: 'checking',
        date: day,
        amount: -500,
        memo: 'note',
        transferAccountId: 'savings',
        cleared: reconciled,
        counterpartCleared: reconciled,
      ),
      allowReconciledChange: true,
    );
    expect((await row(outId)).cleared, reconciled);
    expect((await row(inId)).cleared, reconciled);
  });

  group('the form', () {
    final fmt = AppFormatter(
      locale: 'en',
      currency: 'USD',
      decimalSeparator: '.',
    );

    Future<TransactionFormController> loaded() async {
      final (outId, inId) = await reconciledTransfer();
      final c = TransactionFormController(today: day);
      c.load(
        await row(outId),
        children: const [],
        payeeName: null,
        fmt: fmt,
        counterpart: await row(inId),
      );
      return c;
    }

    test('moving the To leg switches its status off; moving it back '
        'restores it', () async {
      final c = await loaded();
      c.pickTransferAccount('cash');
      expect(c.counterpartCleared, uncleared);
      expect(c.cleared, reconciled);
      c.pickTransferAccount('savings');
      expect(c.counterpartCleared, reconciled);
      c.dispose();
    });

    test(
      'switched on in the new account it is cleared, not reconciled',
      () async {
        final c = await loaded();
        c.pickTransferAccount('cash');
        c.setCounterpartCleared(true);
        expect(c.counterpartCleared, TransactionClearStatus.cleared);
        c.pickAccount('savings');
        expect(c.cleared, uncleared);
        c.setCleared(true);
        expect(c.cleared, TransactionClearStatus.cleared);
        c.dispose();
      },
    );
  });
}
