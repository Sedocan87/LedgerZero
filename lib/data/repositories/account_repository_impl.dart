import 'package:drift/drift.dart';
import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/account.dart' as domain;
import 'package:ledger_zero/domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountsDao _accountsDao;

  AccountRepositoryImpl(this._accountsDao);

  @override
  Future<List<domain.Account>> getAllAccounts() async {
    final accounts = await _accountsDao.getAllAccounts();
    return accounts.map(_mapToDomain).toList();
  }

  @override
  Future<domain.Account?> getAccountById(String id) async {
    final account = await _accountsDao.getAccountById(id);
    return account == null ? null : _mapToDomain(account);
  }

  @override
  Future<void> createAccount(domain.Account account) async {
    await _accountsDao.insertAccount(_mapToCompanion(account));
  }

  @override
  Future<void> updateAccount(domain.Account account) async {
    await _accountsDao.updateAccount(_mapToCompanion(account));
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _accountsDao.deleteAccount(id);
  }

  @override
  Stream<List<domain.Account>> watchAllAccounts() {
    return _accountsDao.watchAllAccounts().map(
          (accounts) => accounts.map(_mapToDomain).toList(),
        );
  }

  domain.Account _mapToDomain(Account account) {
    return domain.Account(
      id: account.id,
      name: account.name,
      type: domain.AccountType.values.firstWhere(
        (e) => e.name == account.type,
        orElse: () => domain.AccountType.checking,
      ),
      currency: account.currency,
      startingBalance: account.startingBalance,
      currentBalance: account.currentBalance,
      isClosed: account.isClosed,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  AccountsCompanion _mapToCompanion(domain.Account account) {
    return AccountsCompanion(
      id: Value(account.id),
      name: Value(account.name),
      type: Value(account.type.name),
      currency: Value(account.currency),
      startingBalance: Value(account.startingBalance),
      currentBalance: Value(account.currentBalance),
      isClosed: Value(account.isClosed),
      createdAt: Value(account.createdAt),
      updatedAt: Value(account.updatedAt),
    );
  }
}
