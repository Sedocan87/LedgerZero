import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';

import '../../helpers/test_database.dart';

/// Personal accounts on one phone: this member's are off-budget and keep a
/// shared balance; the partner's are read-only.
void main() {
  late TestDatabase t;
  late TransactionService service;

  setUp(() {
    t = TestDatabase();
    service = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: UndoService(),
      unitOfWork: t.unitOfWork,
    );
  });

  tearDown(() => t.close());

  /// An account as it arrives from the partner's phone.
  Future<void> addPartnersAccount(String id) async {
    await t.addAccount(id: id, name: 'Their brokerage', startingBalance: 0);
    await t.db.customStatement(
      'UPDATE accounts SET owner_id = ?, on_budget = 0, shared_balance = ? '
      'WHERE id = ?',
      ['partner-member', 777700, id],
    );
  }

  test('a personal account is always off-budget', () async {
    await t.accounts.createAccount(
      const Account(
        id: 'brk',
        name: 'Brokerage',
        type: AccountType.investment,
        owner: AccountOwner.me,
      ),
    );
    final stored = (await t.accounts.getAccountById('brk'))!;
    expect(stored.owner, AccountOwner.me);
    expect(stored.onBudget, isFalse);
  });

  test('the partner\'s account shows the balance their phone shared', () async {
    await addPartnersAccount('theirs');
    final account = (await t.accounts.getAccountById('theirs'))!;
    expect(account.owner, AccountOwner.partner);
    expect(account.isPartners, isTrue);
    expect(account.balance, 777700);
  });

  test('no transfer into the partner\'s account', () async {
    final checking = await t.addAccount(startingBalance: 100000);
    await addPartnersAccount('theirs');
    await expectLater(
      service.save(
        TransactionInput(
          accountId: checking.id,
          transferAccountId: 'theirs',
          date: CalendarDate.today(),
          amount: -1000,
        ),
      ),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.code,
          'code',
          TransactionValidationError.partnerAccount,
        ),
      ),
    );
  });

  test('a transfer the partner made into their account cannot be changed or '
      'deleted here', () async {
    final checking = await t.addAccount(startingBalance: 100000);
    await addPartnersAccount('theirs');
    // Synced from the partner: only the leg in the shared account exists.
    final leg = await t.addTransaction(
      accountId: checking.id,
      amount: -5000,
      transferAccountId: 'theirs',
      transferTransactionId: 'their-leg',
    );

    await expectLater(
      service.save(
        TransactionInput(
          id: leg.id,
          accountId: checking.id,
          transferAccountId: 'theirs',
          date: leg.date,
          amount: -6000,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      service.deleteTransaction(leg.id),
      throwsA(isA<ValidationException>()),
    );
    expect((await t.transactions.getTransactionById(leg.id))!.amount, -5000);
  });

  test(
    'transfers into this member\'s personal account work as usual',
    () async {
      final checking = await t.addAccount(startingBalance: 100000);
      await t.addAccount(
        id: 'brk',
        name: 'Brokerage',
        startingBalance: 50000,
        owner: AccountOwner.me,
      );
      await service.save(
        TransactionInput(
          accountId: checking.id,
          transferAccountId: 'brk',
          date: CalendarDate.today(),
          amount: -10000,
        ),
      );
      expect((await t.accounts.getAccountById('brk'))!.balance, 60000);
      final shared = await t.db
          .customSelect("SELECT shared_balance FROM accounts WHERE id = 'brk'")
          .getSingle();
      expect(shared.read<int>('shared_balance'), 60000);
    },
  );
}
