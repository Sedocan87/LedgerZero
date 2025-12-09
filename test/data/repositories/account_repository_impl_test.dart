import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/database/daos/accounts_dao.dart';
import 'package:ledger_zero/data/repositories/account_repository_impl.dart';
import 'package:ledger_zero/domain/entities/account.dart' as domain;
import 'package:drift/native.dart';

// Since we are testing Repository Logic wrapping DAO, we can use a real DAO with in-memory DB
// OR mock the DAO.
// Given the task is "Test repository implementations", and these implementations mainly wrap DAOs with error handling and mapping,
// using real DAO + in-memory DB provides a true integration test of the data layer.
// However, the task says "Set up unit testing framework", so pure unit tests with mocked DAO are also valid.
// I will use in-memory DB to verify the full stack from Repo -> DAO -> DB works correctly, as this catches more issues.

void main() {
  late AppDatabase database;
  late AccountsDao accountsDao;
  late AccountRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    accountsDao = AccountsDao(database);
    repository = AccountRepositoryImpl(accountsDao);
  });

  tearDown(() async {
    await database.close();
  });

  group('AccountRepositoryImpl', () {
    final testAccount = domain.Account(
      id: '1',
      name: 'Checking',
      type: domain.AccountType.checking,
      currency: 'USD',
      startingBalance: 100.0,
      currentBalance: 100.0,
      isClosed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('createAccount inserts account into database', () async {
      await repository.createAccount(testAccount);

      final retrieved = await repository.getAccountById('1');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Checking'));
      expect(retrieved.type, equals(domain.AccountType.checking));
    });

    test('getAllAccounts returns all inserted accounts', () async {
      await repository.createAccount(testAccount);
      await repository.createAccount(testAccount.copyWith(id: '2', name: 'Savings', type: domain.AccountType.savings));

      final accounts = await repository.getAllAccounts();
      expect(accounts.length, equals(2));
      expect(accounts.any((a) => a.name == 'Checking'), isTrue);
      expect(accounts.any((a) => a.name == 'Savings'), isTrue);
    });

    test('updateAccount modifies existing account', () async {
      await repository.createAccount(testAccount);

      final updated = testAccount.copyWith(name: 'Updated Name', currentBalance: 500.0);
      await repository.updateAccount(updated);

      final retrieved = await repository.getAccountById('1');
      expect(retrieved!.name, equals('Updated Name'));
      expect(retrieved.currentBalance, equals(500.0));
    });

    test('deleteAccount removes account', () async {
      await repository.createAccount(testAccount);
      await repository.deleteAccount('1');

      final retrieved = await repository.getAccountById('1');
      expect(retrieved, isNull);
    });

    test('watchAllAccounts emits updates', () async {
      await repository.createAccount(testAccount);

      final stream = repository.watchAllAccounts();
      expect(stream, emitsInOrder([
        hasLength(1),
        hasLength(2),
      ]));

      // Allow stream subscription to catch up
      await Future.delayed(Duration.zero);

      await repository.createAccount(testAccount.copyWith(id: '2', name: 'Savings'));
    });
  });
}
