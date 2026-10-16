import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/tables/accounts.dart';
import 'package:ledger_zero/data/database/tables/transactions.dart';

part 'accounts_dao.g.dart';

/// An account row together with its computed balance in minor units.
typedef AccountWithBalance = ({Account account, int balance});

@DriftAccessor(tables: [Accounts, Transactions])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// SQL for the computed balance of account alias `a`:
  /// starting balance + SUM(amount) of the account's non-deleted rows that
  /// are not split children (split children are already represented by
  /// their parent's amount).
  static const String balanceExpression =
      'a.starting_balance + COALESCE((SELECT SUM(t.amount) FROM transactions t '
      'WHERE t.account_id = a.id AND t.is_deleted = 0 '
      'AND t.parent_transaction_id IS NULL), 0)';

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
      'SELECT a.*, $balanceExpression AS computed_balance FROM accounts a'
      '${id == null ? '' : ' WHERE a.id = ?'}',
      variables: [if (id != null) Variable.withString(id)],
      readsFrom: {accounts, transactions},
    ).map(
      (row) => (
        account: accounts.map(row.data),
        balance: row.read<int>('computed_balance'),
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
      readsFrom: {accounts, transactions},
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

  /// Sum of all accounts' starting balances (minor units).
  Future<int> getTotalStartingBalance() {
    final total = accounts.startingBalance.sum();
    final query = selectOnly(accounts)..addColumns([total]);
    return query.map((row) => row.read(total) ?? 0).getSingle();
  }
}
