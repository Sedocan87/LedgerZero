import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/sync_tables.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';
import 'package:uuid/uuid.dart';

part 'accounts_dao.g.dart';

/// An account row together with its balance in minor units and its
/// [AccountsDao.ownershipExpression] value.
typedef AccountWithBalance = ({Account account, int balance, int ownership});

@DriftAccessor(tables: [Accounts, Transactions, SyncKv])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// SQL for the computed balance of account alias `a`:
  /// starting balance + SUM(amount) of the account's non-deleted rows that
  /// are not split children (split children are already represented by
  /// their parent's amount).
  ///
  /// Another member's personal account has no transactions here; its
  /// balance is the one its owner's device shared.
  static const String balanceExpression =
      'CASE WHEN a.owner_id IS NOT NULL '
      'AND a.owner_id IS NOT ${AppDatabase.localMemberSql} '
      'THEN COALESCE(a.shared_balance, a.starting_balance) '
      'ELSE a.starting_balance + COALESCE((SELECT SUM(t.amount) '
      'FROM transactions t WHERE t.account_id = a.id AND t.is_deleted = 0 '
      'AND t.parent_transaction_id IS NULL), 0) END';

  /// SQL for who owns account alias `a`: 0 shared, 1 this device's member
  /// (personal), 2 another member (their personal account).
  static const String ownershipExpression =
      'CASE WHEN a.owner_id IS NULL THEN 0 '
      'WHEN a.owner_id = ${AppDatabase.localMemberSql} THEN 1 ELSE 2 END';

  Future<List<Account>> getAllAccounts() => select(accounts).get();

  Future<Account?> getAccountById(String id) =>
      (select(accounts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<int> insertAccount(AccountsCompanion account) =>
      into(accounts).insert(account);

  Future<bool> updateAccount(AccountsCompanion account) =>
      update(accounts).replace(account);

  Future<int> deleteAccount(String id) =>
      (delete(accounts)..where((tbl) => tbl.id.equals(id))).go();

  Stream<List<Account>> watchAllAccounts() => select(accounts).watch();

  Stream<Account?> watchAccount(String id) =>
      (select(accounts)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();

  Selectable<AccountWithBalance> _accountsWithBalance({String? id}) {
    return customSelect(
      'SELECT a.*, $balanceExpression AS computed_balance, '
      '$ownershipExpression AS ownership FROM accounts a'
      '${id == null ? '' : ' WHERE a.id = ?'}',
      variables: [if (id != null) Variable.withString(id)],
      readsFrom: {accounts, transactions, syncKv},
    ).map(
      (row) => (
        account: accounts.map(row.data),
        balance: row.read<int>('computed_balance'),
        ownership: row.read<int>('ownership'),
      ),
    );
  }

  /// All accounts with their computed balances (one query).
  Future<List<AccountWithBalance>> getAllAccountsWithBalance() =>
      _accountsWithBalance().get();

  /// Watches all accounts with their computed balances. Emits whenever an
  /// account or a transaction changes.
  Stream<List<AccountWithBalance>> watchAllAccountsWithBalance() =>
      _accountsWithBalance().watch();

  Future<AccountWithBalance?> getAccountWithBalance(String id) =>
      _accountsWithBalance(id: id).getSingleOrNull();

  Stream<AccountWithBalance?> watchAccountWithBalance(String id) =>
      _accountsWithBalance(id: id).watchSingleOrNull();

  Selectable<MapEntry<String, int>> _balances({String? id}) {
    return customSelect(
      'SELECT a.id AS id, $balanceExpression AS computed_balance '
      'FROM accounts a${id == null ? '' : ' WHERE a.id = ?'}',
      variables: [if (id != null) Variable.withString(id)],
      readsFrom: {accounts, transactions, syncKv},
    ).map(
      (row) =>
          MapEntry(row.read<String>('id'), row.read<int>('computed_balance')),
    );
  }

  /// accountId -> balance in minor units for every account (one grouped
  /// query).
  Future<Map<String, int>> getAccountBalances() async =>
      Map.fromEntries(await _balances().get());

  /// Watches accountId -> balance for every account.
  Stream<Map<String, int>> watchAccountBalances() =>
      _balances().watch().map(Map.fromEntries);

  /// Balance of a single account, or 0 if it does not exist.
  Future<int> getAccountBalance(String id) async =>
      (await _balances(id: id).getSingleOrNull())?.value ?? 0;

  /// Watches the balance of a single account.
  Stream<int> watchAccountBalance(String id) =>
      _balances(id: id).watchSingleOrNull().map((e) => e?.value ?? 0);

  /// Balance counting only cleared and reconciled transactions, optionally
  /// only those dated on or before [upTo] (a calendar day).
  Future<int> getClearedBalance(String id, {DateTime? upTo}) async {
    final row = await customSelect(
      'SELECT a.starting_balance + COALESCE((SELECT SUM(t.amount) '
      'FROM transactions t WHERE t.account_id = a.id AND t.is_deleted = 0 '
      'AND t.parent_transaction_id IS NULL AND t.cleared > 0'
      '${upTo == null ? '' : ' AND t.date <= ?'}), 0) AS b '
      'FROM accounts a WHERE a.id = ?',
      variables: [
        if (upTo != null) Variable.withDateTime(upTo.toUtc()),
        Variable.withString(id),
      ],
      readsFrom: {accounts, transactions},
    ).getSingleOrNull();
    return row?.read<int>('b') ?? 0;
  }

  /// This device's household member id, created on first use (the owner
  /// of personal accounts created here).
  Future<String> localMemberId() {
    return transaction(() async {
      final existing = await (select(
        syncKv,
      )..where((t) => t.key.equals(AppDatabase.memberIdKey))).getSingleOrNull();
      if (existing != null) {
        return existing.value;
      }
      final id = const Uuid().v4();
      await into(
        syncKv,
      ).insert(SyncKvCompanion.insert(key: AppDatabase.memberIdKey, value: id));
      return id;
    });
  }

  /// The stored owner of account [id] (null: shared or missing).
  Future<String?> ownerIdOf(String id) async {
    final query = selectOnly(accounts)
      ..addColumns([accounts.ownerId])
      ..where(accounts.id.equals(id));
    return (await query.getSingleOrNull())?.read(accounts.ownerId);
  }

  /// Whether account [id] has already gone out to the sync folder (this
  /// device knows a synced version of it).
  Future<bool> wasSynced(String id) async {
    final row = await customSelect(
      "SELECT 1 FROM sync_row_versions WHERE sync_table = 'accounts' "
      'AND row_id = ? LIMIT 1',
      variables: [Variable.withString(id)],
    ).getSingleOrNull();
    return row != null;
  }

  /// Whether a sync folder is set up on this device (the derived sync key
  /// is stored; Disconnect forgets it).
  Future<bool> syncConfigured() async {
    final row = await customSelect(
      "SELECT 1 FROM sync_kv WHERE key = 'sync_key' LIMIT 1",
    ).getSingleOrNull();
    return row != null;
  }

  /// Whether account [id] is shared with the household right now: it went
  /// out to the sync folder and sync is still set up. Such an account
  /// cannot become personal (the partner's phone has its transactions);
  /// once sync is disconnected it can.
  Future<bool> isSharedWithHousehold(String id) async =>
      await wasSynced(id) && await syncConfigured();

  /// Queues every transaction and scheduled transaction of account [id] for
  /// upload, e.g. after a personal account became shared (they were held
  /// back until now).
  Future<void> queueHistoryForSync(String id) async {
    const now = "strftime('%Y-%m-%dT%H:%M:%fZ', 'now')";
    await customStatement(
      'INSERT INTO pending_sync_changes '
      '(table_name, record_id, action, changed_at) '
      "SELECT 'transactions', id, 'UPDATE', $now FROM transactions "
      'WHERE account_id = ?1 '
      "UNION ALL SELECT 'scheduled_transactions', id, 'UPDATE', $now "
      'FROM scheduled_transactions WHERE account_id = ?1',
      [id],
    );
  }

  /// Sum of the on-budget accounts' starting balances (minor units).
  Future<int> getBudgetStartingBalance() {
    final total = accounts.startingBalance.sum();
    final query = selectOnly(accounts)
      ..where(accounts.onBudget.equals(true))
      ..addColumns([total]);
    return query.map((row) => row.read(total) ?? 0).getSingle();
  }
}
