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
    test('processDueTransactions creates transaction and updates schedule', () async {
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

       when(mockScheduledRepo.getAllScheduledTransactions())
           .thenAnswer((_) async => [scheduled]);

       when(mockTransactionRepo.createTransaction(any)).thenAnswer((_) async => {});
       when(mockScheduledRepo.updateScheduledTransaction(any)).thenAnswer((_) async => {});
       when(mockNotificationService.scheduleNotification(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate')))
           .thenAnswer((_) async => {});
       when(mockNotificationService.cancelNotification(any)).thenAnswer((_) async => {});

       await service.processDueTransactions();

       // Verify transaction created
       verify(mockTransactionRepo.createTransaction(argThat(
           predicate<Transaction>((t) =>
               t.accountId == 'acc1' &&
               t.amount == 100 &&
               t.date == due
           )
       ))).called(1);

       // Verify schedule updated
       // Next date should be 1 month after due
       final expectedNext = DateTime(due.year, due.month + 1, due.day, due.hour, due.minute);
       verify(mockScheduledRepo.updateScheduledTransaction(argThat(
           predicate<ScheduledTransaction>((t) => t.id == '1' && t.nextDate == expectedNext)
       ))).called(1);

       // Verify notification scheduled
       verify(mockNotificationService.scheduleNotification(
           id: anyNamed('id'),
           title: anyNamed('title'),
           body: anyNamed('body'),
           scheduledDate: anyNamed('scheduledDate')
       )).called(1);
    });

    test('processDueTransactions handles missed occurrences (catch up)', () async {
       final now = DateTime.now();
       final due = now.subtract(const Duration(days: 40)); // Due 40 days ago (more than 1 month)

       final scheduled = ScheduledTransaction(
          id: '1',
          accountId: 'acc1',
          amount: 100,
          nextDate: due,
          frequency: RecurrenceFrequency.monthly,
          interval: 1,
       );

       when(mockScheduledRepo.getAllScheduledTransactions())
           .thenAnswer((_) async => [scheduled]);

       when(mockTransactionRepo.createTransaction(any)).thenAnswer((_) async => {});
       when(mockScheduledRepo.updateScheduledTransaction(any)).thenAnswer((_) async => {});
        when(mockNotificationService.scheduleNotification(
            id: anyNamed('id'),
            title: anyNamed('title'),
            body: anyNamed('body'),
            scheduledDate: anyNamed('scheduledDate')))
           .thenAnswer((_) async => {});
        when(mockNotificationService.cancelNotification(any)).thenAnswer((_) async => {});

       await service.processDueTransactions();

       // Should create 2 transactions:
       // 1. Due date (40 days ago)
       // 2. Due date + 1 month (approx 10 days ago)
       // Next date should be future (approx 20 days from now)

       verify(mockTransactionRepo.createTransaction(any)).called(2);

       // It updates scheduled transaction multiple times (in loop)
       verify(mockScheduledRepo.updateScheduledTransaction(any)).called(2);
    });

    test('processDueTransactions skips if nextDate is null', () async {
       const scheduled = ScheduledTransaction(
          id: '1',
          accountId: 'acc1',
          amount: 100,
          nextDate: null,
       );

       when(mockScheduledRepo.getAllScheduledTransactions())
           .thenAnswer((_) async => [scheduled]);

       await service.processDueTransactions();

       verifyNever(mockTransactionRepo.createTransaction(any));
    });

    test('processDueTransactions schedules notification for future transaction', () async {
      final now = DateTime.now();
      final future = now.add(const Duration(days: 5));

      const scheduled = ScheduledTransaction(
        id: '1',
        accountId: 'acc1',
        amount: 100,
        nextDate: null, // Wait, I need non-null nextDate for this test
      );
      // I need to use copyWith or create new
      final scheduledFuture = scheduled.copyWith(nextDate: future);

      when(mockScheduledRepo.getAllScheduledTransactions())
          .thenAnswer((_) async => [scheduledFuture]);

      when(mockNotificationService.scheduleNotification(
              id: anyNamed('id'),
              title: anyNamed('title'),
              body: anyNamed('body'),
              scheduledDate: anyNamed('scheduledDate')))
          .thenAnswer((_) async => {});
      when(mockNotificationService.cancelNotification(any))
          .thenAnswer((_) async => {});

      await service.processDueTransactions();

      verifyNever(mockTransactionRepo.createTransaction(any));
      verify(mockNotificationService.scheduleNotification(
          id: anyNamed('id'),
          title: anyNamed('title'),
          body: anyNamed('body'),
          scheduledDate: anyNamed('scheduledDate'))).called(1);
    });
  });
}
