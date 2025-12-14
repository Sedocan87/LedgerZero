import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/presentation/providers/payee_provider.dart';
import 'package:ledger_zero/presentation/providers/repository_providers.dart';
import 'package:mockito/mockito.dart';

import '../../mocks/repository_mocks.mocks.dart';

void main() {
  late MockPayeeRepository mockPayeeRepository;
  late MockTransactionRepository mockTransactionRepository;
  late ProviderContainer container;
  late PayeeController controller;

  setUp(() {
    mockPayeeRepository = MockPayeeRepository();
    mockTransactionRepository = MockTransactionRepository();
    container = ProviderContainer(
      overrides: [
        payeeRepositoryProvider.overrideWithValue(mockPayeeRepository),
        transactionRepositoryProvider.overrideWithValue(
          mockTransactionRepository,
        ),
      ],
    );
    controller = container.read(payeeControllerProvider);
  });

  group('PayeeController', () {
    test('deletePayee clears transactions and deletes payee', () async {
      const payeeId = 'p1';
      final transactions = [
        Transaction(
          id: 't1',
          accountId: 'a1',
          date: DateTime.now(),
          amount: 10.0,
          payeeId: payeeId,
        ),
      ];

      when(
        mockTransactionRepository.getTransactions(filter: anyNamed('filter')),
      ).thenAnswer((_) async => transactions);
      when(
        mockTransactionRepository.batchUpdateTransactions(any),
      ).thenAnswer((_) async {});
      when(mockPayeeRepository.deletePayee(payeeId)).thenAnswer((_) async {});

      await controller.deletePayee(payeeId);

      // Verify transactions fetched
      verify(
        mockTransactionRepository.getTransactions(filter: anyNamed('filter')),
      ).called(1);

      // Verify batch update called with null payeeId
      final captured = verify(
        mockTransactionRepository.batchUpdateTransactions(captureAny),
      ).captured;
      final updatedTxs = captured.first as List<Transaction>;
      expect(updatedTxs.length, 1);
      expect(updatedTxs.first.payeeId, isNull);

      // Verify delete called
      verify(mockPayeeRepository.deletePayee(payeeId)).called(1);
    });

    test('deletePayee just deletes payee if no transactions', () async {
      const payeeId = 'p1';
      when(
        mockTransactionRepository.getTransactions(filter: anyNamed('filter')),
      ).thenAnswer((_) async => []);
      when(mockPayeeRepository.deletePayee(payeeId)).thenAnswer((_) async {});

      await controller.deletePayee(payeeId);

      verifyNever(mockTransactionRepository.batchUpdateTransactions(any));
      verify(mockPayeeRepository.deletePayee(payeeId)).called(1);
    });

    test('mergePayees reassigns transactions and deletes source', () async {
      const sourceId = 'source';
      const targetId = 'target';
      const sourcePayee = Payee(id: sourceId, name: 'Source');
      final transactions = [
        Transaction(
          id: 't1',
          accountId: 'a1',
          date: DateTime.now(),
          amount: 10.0,
          payeeId: sourceId,
        ),
      ];

      when(
        mockPayeeRepository.getPayeeById(sourceId),
      ).thenAnswer((_) async => sourcePayee);
      when(
        mockTransactionRepository.getTransactions(filter: anyNamed('filter')),
      ).thenAnswer((_) async => transactions);
      when(
        mockTransactionRepository.batchUpdateTransactions(any),
      ).thenAnswer((_) async {});
      when(mockPayeeRepository.deletePayee(sourceId)).thenAnswer((_) async {});

      await controller.mergePayees(sourceId, targetId);

      // Verify transactions fetched
      verify(
        mockTransactionRepository.getTransactions(filter: anyNamed('filter')),
      ).called(1);

      // Verify batch update called with target payeeId
      final captured = verify(
        mockTransactionRepository.batchUpdateTransactions(captureAny),
      ).captured;
      final updatedTxs = captured.first as List<Transaction>;
      expect(updatedTxs.length, 1);
      expect(updatedTxs.first.payeeId, targetId);

      // Verify delete called
      verify(mockPayeeRepository.deletePayee(sourceId)).called(1);
    });
  });
}
