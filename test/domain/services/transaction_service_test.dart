import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/entities/transaction_filter.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';

class MockUndoService extends Mock implements UndoService {}

void main() {
  late TransactionService transactionService;
  late MockTransactionRepository mockTransactionRepository;
  late MockUndoService mockUndoService;

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    mockUndoService = MockUndoService();
    transactionService = TransactionService(mockTransactionRepository, mockUndoService);
  });

  group('createTransaction', () {
    test('should create a transaction successfully when valid', () async {
      final transaction = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -50.0,
      );

      when(mockTransactionRepository.createTransaction(any))
          .thenAnswer((_) async {});

      await transactionService.createTransaction(transaction);

      verify(mockTransactionRepository.createTransaction(any)).called(1);
    });

    test('should throw ValidationException when amount is zero', () async {
      final transaction = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: 0.0,
      );

      expect(
        () => transactionService.createTransaction(transaction),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(mockTransactionRepository.createTransaction(any));
    });

    test('should set createdAt and updatedAt if not provided', () async {
      final transaction = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -50.0,
      );

      when(mockTransactionRepository.createTransaction(any))
          .thenAnswer((_) async {});

      await transactionService.createTransaction(transaction);

      final captured = verify(mockTransactionRepository.createTransaction(captureAny))
          .captured
          .first as Transaction;

      expect(captured.createdAt, isNotNull);
      expect(captured.updatedAt, isNotNull);
      expect(captured.isDeleted, false);
    });
  });

  group('updateTransaction', () {
    test('should update a transaction successfully when valid', () async {
      final transaction = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -50.0,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      when(mockTransactionRepository.getTransactionById(transaction.id))
          .thenAnswer((_) async => transaction);
      when(mockTransactionRepository.updateTransaction(any))
          .thenAnswer((_) async {});

      await transactionService.updateTransaction(transaction);

      verify(mockTransactionRepository.updateTransaction(any)).called(1);
    });

    test('should update updatedAt field', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 1));
      final transaction = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -50.0,
        createdAt: oldDate,
        updatedAt: oldDate,
      );

      when(mockTransactionRepository.getTransactionById(transaction.id))
          .thenAnswer((_) async => transaction);
      when(mockTransactionRepository.updateTransaction(any))
          .thenAnswer((_) async {});

      await transactionService.updateTransaction(transaction);

      final captured = verify(mockTransactionRepository.updateTransaction(captureAny))
          .captured
          .first as Transaction;

      expect(captured.updatedAt!.isAfter(oldDate), true);
    });

    test('should throw ValidationException when amount is zero', () async {
      final transaction = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: 0.0,
      );

      expect(
        () => transactionService.updateTransaction(transaction),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(mockTransactionRepository.updateTransaction(any));
    });
  });

  group('deleteTransaction', () {
    test('should call deleteLinkedTransaction on repository', () async {
      const id = 'tx1';
      final transaction = Transaction(id: id, accountId: 'acc1', date: DateTime.now(), amount: 10);

      when(mockTransactionRepository.getTransactionById(id))
          .thenAnswer((_) async => transaction);
      when(mockTransactionRepository.getSplitTransactions(id))
          .thenAnswer((_) async => []);
      when(mockTransactionRepository.deleteLinkedTransaction(id))
          .thenAnswer((_) async {});

      await transactionService.deleteTransaction(id);

      verify(mockTransactionRepository.deleteLinkedTransaction(id)).called(1);
    });
  });

  group('createTransferTransaction', () {
    test('should call createTransferTransaction on repository with linked transactions', () async {
      final source = Transaction(
        id: 'tx1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -100.0,
      );
      final dest = Transaction(
        id: 'tx2',
        accountId: 'acc2',
        date: DateTime.now(),
        amount: 100.0,
      );

      when(mockTransactionRepository.createTransferTransaction(any, any))
          .thenAnswer((_) async {});

      await transactionService.createTransferTransaction(source, dest);

      final captured = verify(mockTransactionRepository.createTransferTransaction(captureAny, captureAny)).captured;
      final sourceCaptured = captured[0] as Transaction;
      final destCaptured = captured[1] as Transaction;

      expect(sourceCaptured.transferTransactionId, dest.id);
      expect(sourceCaptured.transferAccountId, dest.accountId);
      expect(destCaptured.transferTransactionId, source.id);
      expect(destCaptured.transferAccountId, source.accountId);
    });
  });

  group('createSplitTransaction', () {
    test('should call createSplitTransaction on repository', () async {
       final parent = Transaction(
        id: 'parent',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -100.0,
      );
      final child1 = Transaction(
        id: 'child1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -60.0,
        categoryId: 'cat1',
      );
       final child2 = Transaction(
        id: 'child2',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -40.0,
        categoryId: 'cat2',
      );

      when(mockTransactionRepository.createSplitTransaction(any, any))
          .thenAnswer((_) async {});

      await transactionService.createSplitTransaction(parent, [child1, child2]);

      verify(mockTransactionRepository.createSplitTransaction(any, any)).called(1);
    });

    test('should throw if sum does not match', () async {
       final parent = Transaction(
        id: 'parent',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -100.0,
      );
      final child1 = Transaction(
        id: 'child1',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -50.0,
      );

      expect(
          () => transactionService.createSplitTransaction(parent, [child1]),
          throwsA(isA<ValidationException>()));
    });
  });

  group('approve/reject/clear/reconcile', () {
      test('approveTransaction sets approved=true', () async {
          final t = Transaction(id: '1', accountId: 'a', date: DateTime.now(), amount: 10);
          when(mockTransactionRepository.getTransactionById('1')).thenAnswer((_) async => t);
          when(mockTransactionRepository.updateTransaction(any)).thenAnswer((_) async {});

          await transactionService.approveTransaction('1');

          final captured = verify(mockTransactionRepository.updateTransaction(captureAny)).captured.first as Transaction;
          expect(captured.approved, true);
      });

      test('rejectTransaction sets approved=false', () async {
          final t = Transaction(id: '1', accountId: 'a', date: DateTime.now(), amount: 10);
          when(mockTransactionRepository.getTransactionById('1')).thenAnswer((_) async => t);
          when(mockTransactionRepository.updateTransaction(any)).thenAnswer((_) async {});

          await transactionService.rejectTransaction('1');

          final captured = verify(mockTransactionRepository.updateTransaction(captureAny)).captured.first as Transaction;
          expect(captured.approved, false);
      });

       test('markAsReconciled sets status to reconciled', () async {
          final t = Transaction(id: '1', accountId: 'a', date: DateTime.now(), amount: 10);
          when(mockTransactionRepository.getTransactions(filter: anyNamed('filter'))).thenAnswer((_) async => [t]);
          when(mockTransactionRepository.batchUpdateTransactions(any)).thenAnswer((_) async {});

          await transactionService.markAsReconciled(['1']);

          final captured = verify(mockTransactionRepository.batchUpdateTransactions(captureAny)).captured.first as List<Transaction>;
          expect(captured.first.cleared, TransactionClearStatus.reconciled);
      });
  });

  group('Search and Duplication Detection', () {
    test('searchTransactions delegates to repository', () async {
      const filter = TransactionFilter(accountIds: ['acc1']);
      const sort = TransactionSort(field: TransactionSortField.date);

      when(mockTransactionRepository.getTransactions(filter: anyNamed('filter'), sort: anyNamed('sort')))
        .thenAnswer((_) async => []);

      await transactionService.searchTransactions(filter: filter, sort: sort);

      verify(mockTransactionRepository.getTransactions(filter: filter, sort: sort)).called(1);
    });

    test('findPotentialDuplicates queries repository with correct filter', () async {
      final date = DateTime(2025, 1, 15);
      final transaction = Transaction(
        id: 'new_tx',
        accountId: 'acc1',
        date: date,
        amount: -50.0,
        payeeId: 'p1',
      );

      final potentialDuplicate = Transaction(
        id: 'dup_tx',
        accountId: 'acc1',
        date: date.subtract(const Duration(days: 1)),
        amount: -50.0,
        payeeId: 'p1',
      );

      when(mockTransactionRepository.getTransactions(filter: anyNamed('filter')))
        .thenAnswer((_) async => [potentialDuplicate, transaction]); // Return itself too

      final duplicates = await transactionService.findPotentialDuplicates(transaction);

      // Should exclude self
      expect(duplicates.length, 1);
      expect(duplicates.first.id, 'dup_tx');

      // Verify filter args
      final captured = verify(mockTransactionRepository.getTransactions(filter: captureAnyNamed('filter'))).captured.first as TransactionFilter;

      expect(captured.minAmount, -50.0);
      expect(captured.maxAmount, -50.0);
      expect(captured.startDate, date.subtract(const Duration(days: 3)));
      expect(captured.endDate, date.add(const Duration(days: 3)));
      expect(captured.payeeIds, ['p1']);
    });
  });
}
