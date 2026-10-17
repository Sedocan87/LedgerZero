import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/services/sync/sync_engine.dart';

import '../../helpers/sync_simulation.dart';

/// Personal accounts in a household: the account (name, owner, balance)
/// syncs, its transactions stay on the owner's phone.
void main() {
  const passphrase = 'correct horse battery staple';
  late FakeSyncFolder folder;
  late SimDevice a;
  late SimDevice b;

  Future<SimDevice> device([SyncEngineConfig? config]) =>
      SimDevice.create(folder, config: config);

  setUp(() async {
    folder = FakeSyncFolder();
    a = await device();
    b = await device();
    await a.engine.createSyncFolder(passphrase);
    await b.engine.joinSyncFolder(passphrase);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  /// On A: shared checking (1,000.00), A's brokerage (5,000.00) with a
  /// deposit and a transfer from checking.
  Future<void> setUpAccounts() async {
    await a.t!.addAccount(id: 'chk', name: 'Checking', startingBalance: 100000);
    await a.t!.addAccount(
      id: 'brk',
      name: 'Brokerage',
      type: AccountType.investment,
      startingBalance: 500000,
      owner: AccountOwner.me,
    );
    await a.t!.addTransaction(id: 'dep', accountId: 'brk', amount: 20000);
    await a.t!.addTransaction(
      id: 'out',
      accountId: 'chk',
      amount: -30000,
      transferAccountId: 'brk',
      transferTransactionId: 'in',
    );
    await a.t!.addTransaction(
      id: 'in',
      accountId: 'brk',
      amount: 30000,
      transferAccountId: 'chk',
      transferTransactionId: 'out',
    );
  }

  Future<int> transactionsIn(SimDevice d, String accountId) => d.count(
    "SELECT COUNT(*) FROM transactions WHERE account_id = '$accountId'",
  );

  test('the partner gets the account and its balance, not its '
      'transactions', () async {
    await setUpAccounts();
    await syncAll([a, b]);

    final mine = (await a.t!.accounts.getAccountById('brk'))!;
    expect(mine.owner, AccountOwner.me);
    expect(mine.onBudget, isFalse);
    expect(mine.balance, 550000);

    final theirs = (await b.t!.accounts.getAccountById('brk'))!;
    expect(theirs.owner, AccountOwner.partner);
    expect(theirs.name, 'Brokerage');
    expect(theirs.balance, 550000);
    expect(await transactionsIn(b, 'brk'), 0);

    // The transfer's leg in the shared account syncs and still names the
    // personal account.
    final out = (await b.t!.transactions.getTransactionById('out'))!;
    expect(out.transferAccountId, 'brk');
    expect((await b.t!.accounts.getAccountById('chk'))!.balance, 70000);

    // Household net worth is the same on both phones.
    Future<int> netWorth(SimDevice d) async =>
        (await d.t!.accounts.getAllAccounts()).fold<int>(
          0,
          (sum, x) => sum + x.balance,
        );
    expect(await netWorth(b), await netWorth(a));
  });

  test(
    'every balance change on the owner\'s phone reaches the partner',
    () async {
      await setUpAccounts();
      await syncAll([a, b]);

      await a.exec("UPDATE transactions SET is_deleted = 1 WHERE id = 'dep'");
      await syncAll([a, b]);
      expect((await b.t!.accounts.getAccountById('brk'))!.balance, 530000);

      final brk = (await a.t!.accounts.getAccountById('brk'))!;
      await a.t!.accounts.updateAccount(brk.copyWith(startingBalance: 400000));
      await a.t!.addTransaction(id: 'dep2', accountId: 'brk', amount: 1234);
      await syncAll([a, b]);
      expect((await b.t!.accounts.getAccountById('brk'))!.balance, 431234);
      expect(await transactionsIn(b, 'brk'), 0);
    },
  );

  test('a shared account has no shared balance', () async {
    await setUpAccounts();
    final rows = await a.rows(
      'SELECT id, shared_balance FROM accounts ORDER BY id',
    );
    expect(rows, [
      {'id': 'brk', 'shared_balance': 550000},
      {'id': 'chk', 'shared_balance': null},
    ]);
  });

  test('the partner\'s account is read-only', () async {
    await setUpAccounts();
    await syncAll([a, b]);
    final theirs = (await b.t!.accounts.getAccountById('brk'))!;
    await expectLater(
      b.t!.accounts.updateAccount(theirs.copyWith(name: 'Mine now')),
      throwsA(anything),
    );
  });

  test('making it shared sends its history', () async {
    await setUpAccounts();
    await syncAll([a, b]);

    final brk = (await a.t!.accounts.getAccountById('brk'))!;
    await a.t!.accounts.updateAccount(brk.copyWith(owner: AccountOwner.shared));
    await syncAll([a, b]);

    final shared = (await b.t!.accounts.getAccountById('brk'))!;
    expect(shared.owner, AccountOwner.shared);
    expect(shared.balance, 550000);
    expect(await transactionsIn(b, 'brk'), 2);
    expect(
      await a.rows("SELECT shared_balance FROM accounts WHERE id = 'brk'"),
      [
        {'shared_balance': null},
      ],
    );
  });

  test('a phone joining later gets no personal transactions from a '
      'snapshot', () async {
    await a.close();
    await b.close();
    folder = FakeSyncFolder();
    const config = SyncEngineConfig(
      kdfParams: fastKdf,
      snapshotEveryFiles: 1,
      compactAfter: Duration.zero,
    );
    a = await device(config);
    b = await device(config);
    await a.engine.createSyncFolder(passphrase);
    await setUpAccounts();
    await a.sync();
    await a.t!.addTransaction(id: 'dep2', accountId: 'brk', amount: 100);
    await a.sync();

    await b.engine.joinSyncFolder(passphrase);
    await b.sync();
    expect((await b.t!.accounts.getAccountById('brk'))!.balance, 550100);
    expect(await transactionsIn(b, 'brk'), 0);
    expect(await transactionsIn(b, 'chk'), 1);
  });

  test('an account counts as synced once it went out', () async {
    await setUpAccounts();
    expect(await a.t!.accounts.wasSynced('brk'), isFalse);
    await a.sync();
    expect(await a.t!.accounts.wasSynced('brk'), isTrue);
    expect(await a.t!.accounts.wasSynced('chk'), isTrue);
  });
}
