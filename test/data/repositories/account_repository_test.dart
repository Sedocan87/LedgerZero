import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/data/database/database.dart';
import 'package:ledger_zero/data/repositories/account_repository_impl.dart';
import 'package:ledger_zero/domain/entities/account.dart' as domain;
import 'package:mockito/mockito.dart';

import 'repository_test_helpers.mocks.dart';

void main() {
  late AccountRepositoryImpl repository;
  late MockAccountsDao mockAccountsDao;

  setUp(() {
    mockAccountsDao = MockAccountsDao();
    repository = AccountRepositoryImpl(mockAccountsDao);
  });

  final tDate = DateTime.parse('2023-01-01T00:00:00Z');

  final tDriftAccount = Account(
    id: 'acc1',
    name: 'Test Account',
    type: 'checking',
    currency: 'USD',
    startingBalance: 100.0,
    currentBalance: 100.0,
    isClosed: false,
    createdAt: tDate,
    updatedAt: tDate,
  );

  final tDomainAccount = domain.Account(
    id: 'acc1',
    name: 'Test Account',
    type: domain.AccountType.checking,
    currency: 'USD',
    startingBalance: 100.0,
    currentBalance: 100.0,
    isClosed: false,
    createdAt: tDate,
    updatedAt: tDate,
  );

  group('getAllAccounts', () {
    test('should return list of accounts from dao', () async {
      // arrange
      when(mockAccountsDao.getAllAccounts())
          .thenAnswer((_) async => [tDriftAccount]);
      // act
      final result = await repository.getAllAccounts();
      // assert
      expect(result, equals([tDomainAccount]));
      verify(mockAccountsDao.getAllAccounts()).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(mockAccountsDao.getAllAccounts()).thenThrow(Exception('DB Error'));
      // act & assert
      expect(() => repository.getAllAccounts(),
          throwsA(isA<DatabaseException>()));
    });
  });

  group('getAccountById', () {
    test('should return account from dao when found', () async {
      // arrange
      when(mockAccountsDao.getAccountById('acc1'))
          .thenAnswer((_) async => tDriftAccount);
      // act
      final result = await repository.getAccountById('acc1');
      // assert
      expect(result, equals(tDomainAccount));
    });

    test('should return null when account not found', () async {
      // arrange
      when(mockAccountsDao.getAccountById('acc1'))
          .thenAnswer((_) async => null);
      // act
      final result = await repository.getAccountById('acc1');
      // assert
      expect(result, isNull);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(mockAccountsDao.getAccountById(any)).thenThrow(Exception('DB Error'));
      // act & assert
      expect(() => repository.getAccountById('acc1'),
          throwsA(isA<DatabaseException>()));
    });
  });

  group('createAccount', () {
    test('should call insertAccount on dao', () async {
      // arrange
      when(mockAccountsDao.insertAccount(any)).thenAnswer((_) async => 1);
      // act
      await repository.createAccount(tDomainAccount);
      // assert
      verify(mockAccountsDao.insertAccount(any)).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(mockAccountsDao.insertAccount(any)).thenThrow(Exception('DB Error'));
      // act & assert
      expect(() => repository.createAccount(tDomainAccount),
          throwsA(isA<DatabaseException>()));
    });
  });

  group('updateAccount', () {
    test('should call updateAccount on dao', () async {
      // arrange
      when(mockAccountsDao.updateAccount(any)).thenAnswer((_) async => true);
      // act
      await repository.updateAccount(tDomainAccount);
      // assert
      verify(mockAccountsDao.updateAccount(any)).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(mockAccountsDao.updateAccount(any)).thenThrow(Exception('DB Error'));
      // act & assert
      expect(() => repository.updateAccount(tDomainAccount),
          throwsA(isA<DatabaseException>()));
    });
  });

  group('deleteAccount', () {
    test('should call deleteAccount on dao', () async {
      // arrange
      when(mockAccountsDao.deleteAccount(any)).thenAnswer((_) async => 1);
      // act
      await repository.deleteAccount('acc1');
      // assert
      verify(mockAccountsDao.deleteAccount('acc1')).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(mockAccountsDao.deleteAccount(any)).thenThrow(Exception('DB Error'));
      // act & assert
      expect(() => repository.deleteAccount('acc1'),
          throwsA(isA<DatabaseException>()));
    });
  });

  group('watchAllAccounts', () {
    test('should stream list of accounts from dao', () {
      // arrange
      when(mockAccountsDao.watchAllAccounts())
          .thenAnswer((_) => Stream.value([tDriftAccount]));
      // act
      final stream = repository.watchAllAccounts();
      // assert
      expect(stream, emits([tDomainAccount]));
    });

    test('should throw DatabaseException when stream emits error', () {
      // arrange
      when(mockAccountsDao.watchAllAccounts())
          .thenAnswer((_) => Stream.error(Exception('DB Error')));
      // act
      final stream = repository.watchAllAccounts();
      // assert
      expect(stream, emitsError(isA<DatabaseException>()));
    });
  });
}
