import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late TransactionService transactionService;
  late MockTransactionRepository mockTransactionRepository;

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    transactionService = TransactionService(mockTransactionRepository);
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
          when(mockTransactionRepository.getTransactionById('1')).thenAnswer((_) async => t);
          when(mockTransactionRepository.updateTransaction(any)).thenAnswer((_) async {});

          await transactionService.markAsReconciled(['1']);

          final captured = verify(mockTransactionRepository.updateTransaction(captureAny)).captured.first as Transaction;
          expect(captured.cleared, TransactionClearStatus.reconciled);
      });
  });
}
