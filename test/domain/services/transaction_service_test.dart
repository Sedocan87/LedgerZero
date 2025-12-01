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
    test('should call deleteTransaction on repository', () async {
      const id = 'tx1';

      when(mockTransactionRepository.deleteTransaction(id))
          .thenAnswer((_) async {});

      await transactionService.deleteTransaction(id);

      verify(mockTransactionRepository.deleteTransaction(id)).called(1);
    });
  });
}
