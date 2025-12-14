import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/data/database/database.dart' as db;
import 'package:ledger_zero/data/repositories/scheduled_transaction_repository_impl.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart'
    as domain;
import 'package:mockito/mockito.dart';

import 'repository_test_helpers.mocks.dart';

void main() {
  late ScheduledTransactionRepositoryImpl repository;
  late MockScheduledTransactionsDao mockDao;

  setUp(() {
    mockDao = MockScheduledTransactionsDao();
    repository = ScheduledTransactionRepositoryImpl(mockDao);
  });

  final tDate = DateTime.parse('2023-01-01T00:00:00Z');

  final tDriftScheduledTransaction = db.ScheduledTransaction(
    id: 'st1',
    accountId: 'acc1',
    payeeId: 'payee1',
    categoryId: 'cat1',
    amount: 100.0,
    frequency: 'monthly',
    interval: 2,
    occurrenceCount: 5,
    nextDate: tDate,
    endDate: tDate.add(const Duration(days: 365)),
    autoApprove: true,
    createdAt: tDate,
  );

  final tDomainScheduledTransaction = domain.ScheduledTransaction(
    id: 'st1',
    accountId: 'acc1',
    payeeId: 'payee1',
    categoryId: 'cat1',
    amount: 100.0,
    frequency: domain.RecurrenceFrequency.monthly,
    interval: 2,
    occurrenceCount: 5,
    nextDate: tDate,
    endDate: tDate.add(const Duration(days: 365)),
    autoApprove: true,
    createdAt: tDate,
  );

  group('getAllScheduledTransactions', () {
    test(
      'should return list of scheduled transactions from dao with correct mapping',
      () async {
        // arrange
        when(
          mockDao.getAllScheduledTransactions(),
        ).thenAnswer((_) async => [tDriftScheduledTransaction]);
        // act
        final result = await repository.getAllScheduledTransactions();
        // assert
        expect(result, equals([tDomainScheduledTransaction]));
        verify(mockDao.getAllScheduledTransactions()).called(1);
      },
    );
  });

  group('getDueScheduledTransactions', () {
    test('should return list of due scheduled transactions from dao', () async {
      // arrange
      final date = DateTime.now();
      when(
        mockDao.getDueScheduledTransactions(date),
      ).thenAnswer((_) async => [tDriftScheduledTransaction]);
      // act
      final result = await repository.getDueScheduledTransactions(date);
      // assert
      expect(result, equals([tDomainScheduledTransaction]));
      verify(mockDao.getDueScheduledTransactions(date)).called(1);
    });
  });

  group('createScheduledTransaction', () {
    test(
      'should call insertScheduledTransaction on dao with correct fields',
      () async {
        // arrange
        when(
          mockDao.insertScheduledTransaction(any),
        ).thenAnswer((_) async => 1);
        // act
        await repository.createScheduledTransaction(
          tDomainScheduledTransaction,
        );
        // assert
        final captured = verify(
          mockDao.insertScheduledTransaction(captureAny),
        ).captured;
        final companion = captured.first as db.ScheduledTransactionsCompanion;

        expect(companion.id.value, equals(tDomainScheduledTransaction.id));
        expect(companion.autoApprove.value, equals(true));
        expect(companion.interval.value, equals(2));
        expect(companion.occurrenceCount.value, equals(5));
      },
    );
  });

  group('updateScheduledTransaction', () {
    test(
      'should call updateScheduledTransaction on dao with correct fields',
      () async {
        // arrange
        when(
          mockDao.updateScheduledTransaction(any),
        ).thenAnswer((_) async => true);
        // act
        await repository.updateScheduledTransaction(
          tDomainScheduledTransaction,
        );
        // assert
        final captured = verify(
          mockDao.updateScheduledTransaction(captureAny),
        ).captured;
        final companion = captured.first as db.ScheduledTransactionsCompanion;

        expect(companion.id.value, equals(tDomainScheduledTransaction.id));
        expect(companion.autoApprove.value, equals(true));
        expect(companion.interval.value, equals(2));
        expect(companion.occurrenceCount.value, equals(5));
      },
    );
  });

  group('skipScheduledTransaction', () {
    test(
      'should update transaction with next date and decremented occurrence count',
      () async {
        // arrange
        when(
          mockDao.getScheduledTransactionById('st1'),
        ).thenAnswer((_) async => tDriftScheduledTransaction);
        when(
          mockDao.updateScheduledTransaction(any),
        ).thenAnswer((_) async => true);

        // act
        await repository.skipScheduledTransaction('st1');

        // assert
        final captured = verify(
          mockDao.updateScheduledTransaction(captureAny),
        ).captured;
        final companion = captured.first as db.ScheduledTransactionsCompanion;

        // Original nextDate was 2023-01-01, interval 2 months
        // Expected: 2023-03-01
        final expectedDate = DateTime.parse('2023-03-01T00:00:00Z');
        expect(companion.nextDate.value, equals(expectedDate));
        expect(companion.occurrenceCount.value, equals(4)); // 5 - 1
      },
    );

    test('should do nothing if transaction not found', () async {
      // arrange
      when(
        mockDao.getScheduledTransactionById('st1'),
      ).thenAnswer((_) async => null);
      // act
      await repository.skipScheduledTransaction('st1');
      // assert
      verifyNever(mockDao.updateScheduledTransaction(any));
    });
  });
}
