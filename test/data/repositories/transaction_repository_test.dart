import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/errors/exceptions.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/data/repositories/transaction_repository_impl.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:mockito/mockito.dart';

import 'repository_test_helpers.mocks.dart';

void main() {
  late TransactionRepositoryImpl repository;
  late MockTransactionsDao mockTransactionsDao;

  setUp(() {
    mockTransactionsDao = MockTransactionsDao();
    repository = TransactionRepositoryImpl(mockTransactionsDao);
  });

  final tDate = DateTime.parse('2023-01-01T00:00:00Z');

  final tDriftTransaction = db.Transaction(
    id: 'tx1',
    accountId: 'acc1',
    date: tDate,
    amount: -50.0,
    payeeId: 'payee1',
    categoryId: 'cat1',
    memo: 'Lunch',
    cleared: 0, // uncleared
    approved: true,
    isDeleted: false,
    transferAccountId: null,
    transferTransactionId: null,
    parentTransactionId: null,
    createdAt: tDate,
    updatedAt: tDate,
  );

  final tDomainTransaction = Transaction(
    id: 'tx1',
    accountId: 'acc1',
    date: tDate,
    amount: -50.0,
    payeeId: 'payee1',
    categoryId: 'cat1',
    memo: 'Lunch',
    cleared: TransactionClearStatus.uncleared,
    approved: true,
    transferAccountId: null,
    transferTransactionId: null,
    createdAt: tDate,
    updatedAt: tDate,
  );

  group('getAllTransactions', () {
    test('should return list of transactions from dao', () async {
      // arrange
      when(
        mockTransactionsDao.getAllTransactions(),
      ).thenAnswer((_) async => [tDriftTransaction]);
      // act
      final result = await repository.getAllTransactions();
      // assert
      expect(result, equals([tDomainTransaction]));
      verify(mockTransactionsDao.getAllTransactions()).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.getAllTransactions(),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.getAllTransactions(),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('getTransactionById', () {
    test('should return transaction from dao when found', () async {
      // arrange
      when(
        mockTransactionsDao.getTransactionById('tx1'),
      ).thenAnswer((_) async => tDriftTransaction);
      // act
      final result = await repository.getTransactionById('tx1');
      // assert
      expect(result, equals(tDomainTransaction));
    });

    test('should return null when transaction not found', () async {
      // arrange
      when(
        mockTransactionsDao.getTransactionById('tx1'),
      ).thenAnswer((_) async => null);
      // act
      final result = await repository.getTransactionById('tx1');
      // assert
      expect(result, isNull);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.getTransactionById(any),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.getTransactionById('tx1'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('createTransaction', () {
    test('should call insertTransaction on dao', () async {
      // arrange
      when(
        mockTransactionsDao.insertTransaction(any),
      ).thenAnswer((_) async => 1);
      // act
      await repository.createTransaction(tDomainTransaction);
      // assert
      verify(mockTransactionsDao.insertTransaction(any)).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.insertTransaction(any),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.createTransaction(tDomainTransaction),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('batchCreateTransactions', () {
    test('should call batchCreateTransactions on dao', () async {
      // arrange
      when(
        mockTransactionsDao.batchCreateTransactions(any),
      ).thenAnswer((_) async {});
      // act
      await repository.batchCreateTransactions([tDomainTransaction]);
      // assert
      verify(mockTransactionsDao.batchCreateTransactions(any)).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.batchCreateTransactions(any),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.batchCreateTransactions([tDomainTransaction]),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('updateTransaction', () {
    test('should call updateTransaction on dao', () async {
      // arrange
      when(
        mockTransactionsDao.updateTransaction(any),
      ).thenAnswer((_) async => true);
      // act
      await repository.updateTransaction(tDomainTransaction);
      // assert
      verify(mockTransactionsDao.updateTransaction(any)).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.updateTransaction(any),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.updateTransaction(tDomainTransaction),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('deleteTransaction', () {
    test('should call softDeleteTransaction on dao', () async {
      // arrange
      when(
        mockTransactionsDao.softDeleteTransaction(any),
      ).thenAnswer((_) async {});
      // act
      await repository.deleteTransaction('tx1');
      // assert
      verify(mockTransactionsDao.softDeleteTransaction('tx1')).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.softDeleteTransaction(any),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.deleteTransaction('tx1'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('watchAllTransactions', () {
    test('should stream list of transactions from dao', () {
      // arrange
      when(
        mockTransactionsDao.watchAllTransactions(),
      ).thenAnswer((_) => Stream.value([tDriftTransaction]));
      // act
      final stream = repository.watchAllTransactions();
      // assert
      expect(stream, emits([tDomainTransaction]));
    });

    test('should throw DatabaseException when stream emits error', () {
      // arrange
      when(
        mockTransactionsDao.watchAllTransactions(),
      ).thenAnswer((_) => Stream.error(Exception('DB Error')));
      // act
      final stream = repository.watchAllTransactions();
      // assert
      expect(stream, emitsError(isA<DatabaseException>()));
    });
  });

  group('getTransactionsByAccount', () {
    test('should return list of transactions for account', () async {
      // arrange
      when(
        mockTransactionsDao.getTransactionsByAccount('acc1'),
      ).thenAnswer((_) async => [tDriftTransaction]);
      // act
      final result = await repository.getTransactionsByAccount('acc1');
      // assert
      expect(result, equals([tDomainTransaction]));
      verify(mockTransactionsDao.getTransactionsByAccount('acc1')).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.getTransactionsByAccount(any),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.getTransactionsByAccount('acc1'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('watchTransactionsByAccount', () {
    test('should stream list of transactions for account', () {
      // arrange
      when(
        mockTransactionsDao.watchTransactionsByAccount('acc1'),
      ).thenAnswer((_) => Stream.value([tDriftTransaction]));
      // act
      final stream = repository.watchTransactionsByAccount('acc1');
      // assert
      expect(stream, emits([tDomainTransaction]));
    });

    test('should throw DatabaseException when stream emits error', () {
      // arrange
      when(
        mockTransactionsDao.watchTransactionsByAccount(any),
      ).thenAnswer((_) => Stream.error(Exception('DB Error')));
      // act
      final stream = repository.watchTransactionsByAccount('acc1');
      // assert
      expect(stream, emitsError(isA<DatabaseException>()));
    });
  });

  group('getTransactionsByDateRange', () {
    final tStart = DateTime.parse('2022-12-31T00:00:00Z');
    final tEnd = DateTime.parse('2023-01-02T00:00:00Z');

    test('should return list of transactions in range', () async {
      // arrange
      when(
        mockTransactionsDao.getTransactionsByDateRange(tStart, tEnd),
      ).thenAnswer((_) async => [tDriftTransaction]);
      // act
      final result = await repository.getTransactionsByDateRange(tStart, tEnd);
      // assert
      expect(result, equals([tDomainTransaction]));
      verify(
        mockTransactionsDao.getTransactionsByDateRange(tStart, tEnd),
      ).called(1);
    });

    test('should throw DatabaseException when dao fails', () async {
      // arrange
      when(
        mockTransactionsDao.getTransactionsByDateRange(any, any),
      ).thenThrow(Exception('DB Error'));
      // act & assert
      expect(
        () => repository.getTransactionsByDateRange(tStart, tEnd),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
