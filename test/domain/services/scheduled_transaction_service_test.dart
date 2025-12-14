import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/domain/entities/scheduled_transaction.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/services/scheduled_transaction_service.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import '../../mocks/repository_mocks.mocks.dart';
import '../../mocks/service_mocks.mocks.dart';

void main() {
  late MockScheduledTransactionRepository mockScheduledRepo;
  late MockTransactionRepository mockTransactionRepo;
  late MockNotificationService mockNotificationService;
  late ScheduledTransactionService service;
  const uuid = Uuid();

  setUp(() {
    mockScheduledRepo = MockScheduledTransactionRepository();
    mockTransactionRepo = MockTransactionRepository();
    mockNotificationService = MockNotificationService();
    service = ScheduledTransactionService(
      mockScheduledRepo,
      mockTransactionRepo,
      mockNotificationService,
      uuid,
    );
  });

  group('ScheduledTransactionService', () {
    test(
      'processDueTransactions creates transaction and updates schedule',
      () async {
        final now = DateTime.now();
        final due = now.subtract(const Duration(days: 1)); // Due yesterday

        final scheduled = ScheduledTransaction(
          id: '1',
          accountId: 'acc1',
          amount: 100,
          nextDate: due,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
        );

        // Mock getDueScheduledTransactions instead of getAllScheduledTransactions
        when(
          mockScheduledRepo.getDueScheduledTransactions(any),
        ).thenAnswer((_) async => [scheduled]);

        when(
          mockTransactionRepo.batchCreateTransactions(any),
        ).thenAnswer((_) async => {});
        when(
          mockScheduledRepo.updateScheduledTransaction(any),
        ).thenAnswer((_) async => {});
        when(
          mockNotificationService.scheduleNotification(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate'),
          ),
        ).thenAnswer((_) async => {});
        when(
          mockNotificationService.cancelNotification(any),
        ).thenAnswer((_) async => {});

        await service.processDueTransactions();

        // Verify transaction created via batch
        verify(
          mockTransactionRepo.batchCreateTransactions(
            argThat(
              predicate<List<Transaction>>(
                (list) =>
                    list.length == 1 &&
                    list.first.accountId == 'acc1' &&
                    list.first.amount == 100 &&
                    list.first.date == due,
              ),
            ),
          ),
        ).called(1);

        // Verify schedule updated
        // Next date should be 1 month after due
        final expectedNext = DateTime(
          due.year,
          due.month + 1,
          due.day,
          due.hour,
          due.minute,
        );
        verify(
          mockScheduledRepo.updateScheduledTransaction(
            argThat(
              predicate<ScheduledTransaction>(
                (t) => t.id == '1' && t.nextDate == expectedNext,
              ),
            ),
          ),
        ).called(1);

        // Verify notification scheduled
        verify(
          mockNotificationService.scheduleNotification(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate'),
          ),
        ).called(1);
      },
    );

    test(
      'processDueTransactions handles missed occurrences (catch up)',
      () async {
        final now = DateTime.now();
        final due = now.subtract(
          const Duration(days: 40),
        ); // Due 40 days ago (more than 1 month)

        final scheduled = ScheduledTransaction(
          id: '1',
          accountId: 'acc1',
          amount: 100,
          nextDate: due,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
        );

        when(
          mockScheduledRepo.getDueScheduledTransactions(any),
        ).thenAnswer((_) async => [scheduled]);

        when(
          mockTransactionRepo.batchCreateTransactions(any),
        ).thenAnswer((_) async => {});
        when(
          mockScheduledRepo.updateScheduledTransaction(any),
        ).thenAnswer((_) async => {});
        when(
          mockNotificationService.scheduleNotification(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate'),
          ),
        ).thenAnswer((_) async => {});
        when(
          mockNotificationService.cancelNotification(any),
        ).thenAnswer((_) async => {});

        await service.processDueTransactions();

        // Should create 2 transactions:
        // 1. Due date (40 days ago)
        // 2. Due date + 1 month (approx 10 days ago)
        // Next date should be future (approx 20 days from now)

        verify(
          mockTransactionRepo.batchCreateTransactions(
            argThat(predicate<List<Transaction>>((list) => list.length == 2)),
          ),
        ).called(1);

        // Verify update called once (optimization)
        verify(mockScheduledRepo.updateScheduledTransaction(any)).called(1);
      },
    );

    test('processDueTransactions skips if nextDate is null', () async {
      const scheduled = ScheduledTransaction(
        id: '1',
        accountId: 'acc1',
        amount: 100,
        nextDate: null,
      );

      when(
        mockScheduledRepo.getDueScheduledTransactions(any),
      ).thenAnswer((_) async => [scheduled]);

      await service.processDueTransactions();

      verifyNever(mockTransactionRepo.batchCreateTransactions(any));
    });

    test(
      'processDueTransactions schedules notification for future transaction',
      () async {
        // Logic changed: processDueTransactions uses getDueScheduledTransactions.
        // If a transaction is NOT due, it won't even be returned by getDueScheduledTransactions.
        // So this test case is slightly different. If the repository returns a transaction
        // that is NOT due (e.g. repo bug or whatever), the service handles it.
        // But for testing purposes, we simulate the repo returning it.

        final now = DateTime.now();
        final future = now.add(const Duration(days: 5));

        final scheduled = ScheduledTransaction(
          id: '1',
          accountId: 'acc1',
          amount: 100,
          nextDate: future,
        );

        when(
          mockScheduledRepo.getDueScheduledTransactions(any),
        ).thenAnswer((_) async => [scheduled]);

        when(
          mockNotificationService.scheduleNotification(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate'),
          ),
        ).thenAnswer((_) async => {});
        when(
          mockNotificationService.cancelNotification(any),
        ).thenAnswer((_) async => {});

        await service.processDueTransactions();

        verifyNever(mockTransactionRepo.batchCreateTransactions(any));
        verify(
          mockNotificationService.scheduleNotification(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate'),
          ),
        ).called(1);
      },
    );
  });
}
