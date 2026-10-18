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
      final accounts = await _accountsDao.getAllAccountsWithBalance();
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
      final account = await _accountsDao.getAccountWithBalance(id);
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
      await _accountsDao.insertAccount(
        await _mapToCompanion(account, isInsert: true),
      );
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
      if (account.isPartners) {
        throw StateError('The partner\'s account ${account.id} is read-only');
      }
      final wasPersonal = await _accountsDao.ownerIdOf(account.id) != null;
      if (!wasPersonal &&
          account.isPersonal &&
          await _accountsDao.isSharedWithHousehold(account.id)) {
        throw AccountSharedException(account.id);
      }
      await _accountsDao.transaction(() async {
        await _accountsDao.updateAccount(await _mapToCompanion(account));
        if (wasPersonal && !account.isPersonal) {
          await _accountsDao.queueHistoryForSync(account.id);
        }
      });
      Logger.info('Account updated successfully: ${account.id}');
    } on AccountSharedException {
      rethrow;
    } catch (e, stackTrace) {
      Logger.error('Failed to update account ${account.id}', e, stackTrace);
      throw DatabaseException('Failed to update account ${account.id}', e);
    }
  }

  @override
  Future<bool> wasSynced(String id) async {
    try {
      return await _accountsDao.isSharedWithHousehold(id);
    } catch (e, stackTrace) {
      Logger.error('Failed to read the sync state of $id', e, stackTrace);
      throw DatabaseException('Failed to read the sync state of $id', e);
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
    return _accountsDao
        .watchAllAccountsWithBalance()
        .map((accounts) {
          return accounts.map(_mapToDomain).toList();
        })
        .handleError((error, stackTrace) {
          Logger.error('Error in watchAllAccounts stream', error, stackTrace);
          throw DatabaseException('Error watching accounts', error);
        });
  }

  @override
  Stream<domain.Account?> watchAccount(String id) {
    return _accountsDao
        .watchAccountWithBalance(id)
        .map((account) => account == null ? null : _mapToDomain(account))
        .handleError((error, stackTrace) {
          Logger.error('Error watching account $id', error, stackTrace);
          throw DatabaseException('Error watching account $id', error);
        });
  }

  @override
  Future<Map<String, int>> getAccountBalances() async {
    try {
      return await _accountsDao.getAccountBalances();
    } catch (e, stackTrace) {
      Logger.error('Failed to compute account balances', e, stackTrace);
      throw DatabaseException('Failed to compute account balances', e);
    }
  }

  @override
  Stream<Map<String, int>> watchAccountBalances() {
    return _accountsDao.watchAccountBalances().handleError((error, stackTrace) {
      Logger.error('Error watching account balances', error, stackTrace);
      throw DatabaseException('Error watching account balances', error);
    });
  }

  @override
  Future<int> getAccountBalance(String id) async {
    try {
      return await _accountsDao.getAccountBalance(id);
    } catch (e, stackTrace) {
      Logger.error('Failed to compute balance of $id', e, stackTrace);
      throw DatabaseException('Failed to compute balance of $id', e);
    }
  }

  @override
  Future<int> getClearedBalance(String id, {DateTime? upTo}) async {
    try {
      return await _accountsDao.getClearedBalance(id, upTo: upTo);
    } catch (e, stackTrace) {
      Logger.error('Failed to compute cleared balance of $id', e, stackTrace);
      throw DatabaseException('Failed to compute cleared balance of $id', e);
    }
  }

  @override
  Future<int> getBudgetStartingBalance() async {
    try {
      return await _accountsDao.getBudgetStartingBalance();
    } catch (e, stackTrace) {
      Logger.error('Failed to sum starting balances', e, stackTrace);
      throw DatabaseException('Failed to sum starting balances', e);
    }
  }

  domain.Account _mapToDomain(AccountWithBalance row) {
    final account = row.account;
    return domain.Account(
      id: account.id,
      name: account.name,
      type: domain.AccountType.values.firstWhere(
        (e) => e.name == account.type,
        orElse: () => domain.AccountType.checking,
      ),
      currency: account.currency,
      startingBalance: account.startingBalance,
      balance: row.balance,
      isClosed: account.isClosed,
      onBudget: account.onBudget,
      owner: switch (row.ownership) {
        1 => domain.AccountOwner.me,
        2 => domain.AccountOwner.partner,
        _ => domain.AccountOwner.shared,
      },
      color: account.color,
      icon: account.icon,
      notes: account.notes,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  /// The balance is computed and never written; the shared balance of a
  /// personal account is kept by triggers. A personal account is always
  /// off-budget.
  Future<AccountsCompanion> _mapToCompanion(
    domain.Account account, {
    bool isInsert = false,
  }) async {
    final now = DateTime.now().toUtc();
    final ownerId = switch (account.owner) {
      domain.AccountOwner.shared => null,
      domain.AccountOwner.me => await _accountsDao.localMemberId(),
      domain.AccountOwner.partner => await _accountsDao.ownerIdOf(account.id),
    };
    return AccountsCompanion(
      id: Value(account.id),
      name: Value(account.name),
      type: Value(account.type.name),
      currency: Value(account.currency),
      startingBalance: Value(account.startingBalance),
      isClosed: Value(account.isClosed),
      onBudget: Value(account.onBudget && !account.isPersonal),
      ownerId: Value(ownerId),
      color: Value(account.color),
      icon: Value(account.icon),
      notes: Value(account.notes),
      createdAt: Value(account.createdAt?.toUtc() ?? (isInsert ? now : null)),
      updatedAt: Value(now),
    );
  }
}
