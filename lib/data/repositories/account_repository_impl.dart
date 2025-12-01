import 'package:drift/drift.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/domain/entities/account.dart' as domain;
import 'package:ledger_zero/domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AccountsDao _accountsDao;

  AccountRepositoryImpl(this._accountsDao);

  @override
  Future<List<domain.Account>> getAllAccounts() async {
    try {
      Logger.debug('Fetching all accounts');
      final accounts = await _accountsDao.getAllAccounts();
      Logger.debug('Fetched ${accounts.length} accounts');
      return accounts.map(_mapToDomain).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch accounts', e, stackTrace);
      throw DatabaseException('Failed to fetch accounts', e);
    }
  }

  @override
  Future<domain.Account?> getAccountById(String id) async {
    try {
      Logger.debug('Fetching account with id: $id');
      final account = await _accountsDao.getAccountById(id);
      Logger.debug('Account found: ${account != null}');
      return account == null ? null : _mapToDomain(account);
    } catch (e, stackTrace) {
      Logger.error('Failed to fetch account $id', e, stackTrace);
      throw DatabaseException('Failed to fetch account $id', e);
    }
  }

  @override
  Future<void> createAccount(domain.Account account) async {
    try {
      Logger.debug('Creating account: ${account.name}');
      await _accountsDao.insertAccount(_mapToCompanion(account));
      Logger.info('Account created successfully: ${account.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to create account ${account.id}', e, stackTrace);
      throw DatabaseException('Failed to create account ${account.id}', e);
    }
  }

  @override
  Future<void> updateAccount(domain.Account account) async {
    try {
      Logger.debug('Updating account: ${account.id}');
      await _accountsDao.updateAccount(_mapToCompanion(account));
      Logger.info('Account updated successfully: ${account.id}');
    } catch (e, stackTrace) {
      Logger.error('Failed to update account ${account.id}', e, stackTrace);
      throw DatabaseException('Failed to update account ${account.id}', e);
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    try {
      Logger.debug('Deleting account: $id');
      await _accountsDao.deleteAccount(id);
      Logger.info('Account deleted successfully: $id');
    } catch (e, stackTrace) {
      Logger.error('Failed to delete account $id', e, stackTrace);
      throw DatabaseException('Failed to delete account $id', e);
    }
  }

  @override
  Stream<List<domain.Account>> watchAllAccounts() {
    return _accountsDao.watchAllAccounts().map(
      (accounts) {
        return accounts.map(_mapToDomain).toList();
      },
    ).handleError((error, stackTrace) {
      Logger.error('Error in watchAllAccounts stream', error, stackTrace);
      throw DatabaseException('Error watching accounts', error);
    });
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
