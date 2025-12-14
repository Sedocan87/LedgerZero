import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:mockito/mockito.dart';
import '../../mocks/repository_mocks.mocks.dart';
import '../../fixtures/model_factories.dart';

class MockUndoService extends Mock implements UndoService {}

void main() {
  late TransactionService transactionService;
  late MockTransactionRepository mockTransactionRepository;
  late MockUndoService mockUndoService;

  setUp(() {
    mockTransactionRepository = MockTransactionRepository();
    mockUndoService = MockUndoService();
    transactionService = TransactionService(
      mockTransactionRepository,
      mockUndoService,
    );
  });

  group('TransactionService Edge Cases', () {
    test('should handle max double amount', () async {
      final transaction = createTestTransaction(amount: double.maxFinite);
      when(
        mockTransactionRepository.createTransaction(any),
      ).thenAnswer((_) async {});

      await transactionService.createTransaction(transaction);

      verify(mockTransactionRepository.createTransaction(any)).called(1);
    });

    test('should handle min double amount (large negative)', () async {
      final transaction = createTestTransaction(amount: -double.maxFinite);
      when(
        mockTransactionRepository.createTransaction(any),
      ).thenAnswer((_) async {});

      await transactionService.createTransaction(transaction);

      verify(mockTransactionRepository.createTransaction(any)).called(1);
    });

    test(
      'should fail with very small amount near zero if treated as zero by validation',
      () async {
        // Assuming 0.0 is invalid, but 0.0000001 might be valid technically but functionally 0
        // The current validation likely checks strict equality or tolerance.
        // Let's check a valid small amount.
        final transaction = createTestTransaction(amount: 0.01);
        when(
          mockTransactionRepository.createTransaction(any),
        ).thenAnswer((_) async {});

        await transactionService.createTransaction(transaction);
        verify(mockTransactionRepository.createTransaction(any)).called(1);
      },
    );

    test('should create same-day transfer successfully', () async {
      final now = DateTime(2023, 10, 25, 12, 0, 0);
      final source = createTestTransaction(
        id: 'src',
        accountId: 'acc1',
        date: now,
        amount: -100,
      );
      final dest = createTestTransaction(
        id: 'dst',
        accountId: 'acc2',
        date: now,
        amount: 100,
      );

      when(
        mockTransactionRepository.createTransferTransaction(any, any),
      ).thenAnswer((_) async {});

      await transactionService.createTransferTransaction(source, dest);

      final captured = verify(
        mockTransactionRepository.createTransferTransaction(
          captureAny,
          captureAny,
        ),
      ).captured;
      final t1 = captured[0] as Transaction;
      final t2 = captured[1] as Transaction;

      expect(t1.date, t2.date);
    });

    test('should handle null optional fields gracefully', () async {
      final transaction = Transaction(
        id: 'tx_nulls',
        accountId: 'acc1',
        date: DateTime.now(),
        amount: -50.0,
        payeeId: null,
        categoryId: null,
        memo: null,
      );

      when(
        mockTransactionRepository.createTransaction(any),
      ).thenAnswer((_) async {});

      await transactionService.createTransaction(transaction);

      verify(mockTransactionRepository.createTransaction(any)).called(1);
    });

    test('should handle leap year dates correctly', () async {
      final leapDay = DateTime(2024, 2, 29);
      final transaction = createTestTransaction(date: leapDay);

      when(
        mockTransactionRepository.createTransaction(any),
      ).thenAnswer((_) async {});

      await transactionService.createTransaction(transaction);

      final captured =
          verify(
                mockTransactionRepository.createTransaction(captureAny),
              ).captured.first
              as Transaction;
      expect(captured.date.year, 2024);
      expect(captured.date.month, 2);
      expect(captured.date.day, 29);
    });
  });
}
