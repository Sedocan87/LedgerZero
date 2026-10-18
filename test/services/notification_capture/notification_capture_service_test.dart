import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/domain/entities/payee.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/domain/services/undo_service.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_service.dart';
import 'package:ledger_zero/services/rules/rule_matching_service.dart';

import '../../helpers/fake_notification_capture_channel.dart';
import '../../helpers/test_database.dart';

void main() {
  late TestDatabase t;
  late FakeNotificationCaptureChannel channel;
  late UndoService undo;
  late NotificationCaptureService service;
  late String accountId;

  final postedAt = DateTime(2026, 10, 14, 18, 30);
  var nextId = 0;

  String capture(
    String text, {
    String? title,
    String package = 'bank.app',
    DateTime? at,
  }) {
    final id = 'n${++nextId}';
    channel.queue.add(
      CapturedNotification(
        id: id,
        packageName: package,
        appLabel: 'My Bank',
        title: title,
        text: text,
        postedAt: at ?? postedAt,
      ),
    );
    return id;
  }

  CaptureStatus statusOf(String id) =>
      channel.queue.singleWhere((n) => n.id == id).status;

  setUp(() async {
    t = TestDatabase();
    channel = FakeNotificationCaptureChannel();
    undo = UndoService();
    final transactions = TransactionService(
      transactionRepository: t.transactions,
      payeeRepository: t.payees,
      accountRepository: t.accounts,
      undoService: undo,
      unitOfWork: t.unitOfWork,
      ruleMatchingService: RuleMatchingService(
        t.payees,
        t.transactions,
        t.rules,
      ),
    );
    service = NotificationCaptureService(
      channel: channel,
      transactions: transactions,
      transactionRepository: t.transactions,
      accounts: t.accounts,
      payees: t.payees,
    );
    accountId = (await t.addAccount(name: 'Visa', currency: 'EUR')).id;
    channel.sources = [
      CaptureSource(
        packageName: 'bank.app',
        label: 'My Bank',
        accountId: accountId,
      ),
    ];
  });

  tearDown(() => t.close());

  test('a card payment becomes an unapproved transaction', () async {
    final id = capture('You spent €12.50 at REWE');

    final result = await service.processPending();

    expect(result.added, 1);
    expect(await channel.pending(), isEmpty);
    final rows = await t.transactions.getAllTransactions();
    expect(rows, hasLength(1));
    final tx = rows.single;
    // Kept in the log with the transaction it became.
    expect(statusOf(id), CaptureStatus.added);
    expect(channel.queue.single.transactionId, tx.id);
    expect(tx.accountId, accountId);
    expect(tx.amount, -1250);
    expect(tx.approved, isFalse);
    expect(tx.date, CalendarDate.normalize(postedAt));
    final payee = await t.payees.getPayeeById(tx.payeeId!);
    expect(payee!.name, 'REWE');
    // Not on the undo stack: Undo must not revert it unseen.
    expect(undo.canUndo, isFalse);
  });

  test('a known payee and its last category are reused', () async {
    final groceries = await t.categoryId('Groceries');
    await t.payees.createPayee(
      Payee(id: 'p-rewe', name: 'REWE', autoCategoryId: groceries),
    );
    capture('Kartenzahlung 8,20 EUR bei rewe');

    await service.processPending();

    final tx = (await t.transactions.getAllTransactions()).single;
    expect(tx.payeeId, 'p-rewe');
    expect(tx.categoryId, groceries);
  });

  test('a refund is an inflow', () async {
    capture('Refund of €19.99 from Zalando');

    await service.processPending();

    final tx = (await t.transactions.getAllTransactions()).single;
    expect(tx.amount, 1999);
  });

  test('without a merchant the notification text becomes the memo', () async {
    capture('Card payment of €3.20', title: 'My Bank');

    await service.processPending();

    final tx = (await t.transactions.getAllTransactions()).single;
    expect(tx.payeeId, isNull);
    expect(tx.memo, 'My Bank: Card payment of €3.20');
  });

  test('declined payments and balance notices are skipped', () async {
    final declined = capture('Your payment of €50.00 at Shell was declined');
    final balance = capture('Available balance: €230.00');

    final result = await service.processPending();

    expect(result.ignored, 2);
    expect(await channel.pending(), isEmpty);
    expect(statusOf(declined), CaptureStatus.skipped);
    expect(statusOf(balance), CaptureStatus.skipped);
    expect(await t.transactions.getAllTransactions(), isEmpty);
  });

  test('unreadable, foreign-currency and unlinked captures are held', () async {
    capture('You have a new message');
    capture(r'You spent $20.00 at Walmart');
    capture('You spent €5.00 at Lidl', package: 'other.app');
    channel.sources.add(
      const CaptureSource(packageName: 'other.app', label: 'Other'),
    );

    final result = await service.processPending();

    expect(result.added, 0);
    expect(result.held, 3);
    expect(channel.queue, hasLength(3));
    final held = await service.held();
    expect(held.map((h) => h.reason), [
      CaptureHoldReason.unreadable,
      CaptureHoldReason.foreignCurrency,
      CaptureHoldReason.noAccount,
    ]);

    await service.dismiss([held.first.notification.id]);
    expect(await channel.pending(), hasLength(2));
    expect(statusOf(held.first.notification.id), CaptureStatus.dismissed);
  });

  test('captures of an app that is no longer watched are dropped', () async {
    capture('You spent €5.00 at Lidl', package: 'gone.app');

    final result = await service.processPending();

    expect(result.ignored, 1);
    expect(channel.queue, isEmpty);
  });

  test('removing a source deletes its captures', () async {
    channel.sources.add(
      const CaptureSource(packageName: 'other.app', label: 'Other'),
    );
    capture('You have a new message', package: 'other.app');
    capture('You have a new message');

    await service.removeSource('other.app');

    expect(channel.sources.map((s) => s.packageName), ['bank.app']);
    expect(channel.queue.map((n) => n.packageName), ['bank.app']);
  });

  test('concurrent runs book each capture once', () async {
    capture('You spent €1.00 at A');
    capture('You spent €2.00 at B');

    await Future.wait([service.processPending(), service.processPending()]);
    // The follow-up pass started by the second call.
    await pumpEventQueue();

    expect(await t.transactions.getAllTransactions(), hasLength(2));
  });

  group('history', () {
    test(
      'shows why a notification was skipped and adds it on request',
      () async {
        final id = capture('Your payment of €50.00 at Shell was declined');
        await service.processPending();

        final entry = (await service.history()).single;
        expect(entry.status, CaptureStatus.skipped);
        expect(entry.parse.ignoredPhrase, 'declined');
        expect(entry.canAdd, isTrue);

        expect(await service.addAgain([id]), 1);

        final tx = (await t.transactions.getAllTransactions()).single;
        expect(tx.amount, -5000);
        expect(tx.approved, isFalse);
        expect(statusOf(id), CaptureStatus.added);
      },
    );

    test('a deleted transaction can be added again', () async {
      final id = capture('You spent €12.50 at REWE');
      await service.processPending();
      final tx = (await t.transactions.getAllTransactions()).single;

      var entry = (await service.history()).single;
      expect(entry.likelyDuplicate, isTrue);
      expect(entry.transactionDeleted, isFalse);

      await t.transactions.deleteTransaction(tx.id);
      entry = (await service.history()).single;
      expect(entry.likelyDuplicate, isFalse);
      expect(entry.transactionDeleted, isTrue);

      expect(await service.addAgain([id]), 1);
      expect(await t.transactions.getAllTransactions(), hasLength(1));
    });

    test('a matching transaction entered by hand is flagged', () async {
      capture('Your payment of €7.40 at Bakery was declined');
      await service.processPending();
      await t.addTransaction(
        accountId: accountId,
        amount: -740,
        date: CalendarDate.normalize(postedAt.add(const Duration(days: 1))),
      );

      expect((await service.history()).single.likelyDuplicate, isTrue);
    });

    test('filters by app and date, newest first', () async {
      channel.sources.add(
        CaptureSource(
          packageName: 'other.app',
          label: 'Other',
          accountId: accountId,
        ),
      );
      final early = capture(
        'You spent €1.00 at A',
        at: DateTime(2026, 10, 1, 9),
      );
      final late = capture('You spent €2.00 at B');
      capture('You spent €3.00 at C', package: 'other.app');
      await service.processPending();

      final bank = await service.history(packageName: 'bank.app');
      expect(bank.map((e) => e.notification.id), [late, early]);

      final october14 = await service.history(
        from: DateTime(2026, 10, 14),
        toExclusive: DateTime(2026, 10, 15),
        packageName: 'bank.app',
      );
      expect(october14.map((e) => e.notification.id), [late]);
    });

    test('waiting and blocked notifications are not added again', () async {
      channel.sources.add(
        const CaptureSource(packageName: 'other.app', label: 'Other'),
      );
      final unlinked = capture('You spent €5.00 at Lidl', package: 'other.app');
      final unread = capture('You have a new message');

      final entries = await service.history();
      expect(entries.every((e) => !e.canAdd), isTrue);

      expect(await service.addAgain([unlinked, unread]), 0);
      expect(await t.transactions.getAllTransactions(), isEmpty);
    });

    test(
      'notifications showing when the app is added are only offered',
      () async {
        channel.showing['bank.app'] = [
          CapturedNotification(
            id: 'shown',
            packageName: 'bank.app',
            appLabel: 'My Bank',
            text: 'You spent €4.20 at Kiosk',
            postedAt: postedAt,
          ),
        ];

        expect(await service.captureShowing('bank.app'), 1);
        expect((await service.processPending()).added, 0);
        expect(await t.transactions.getAllTransactions(), isEmpty);

        final entry = (await service.history()).single;
        expect(entry.status, CaptureStatus.found);
        expect(entry.canAdd, isTrue);
        expect(await service.addAgain(['shown']), 1);
        expect((await t.transactions.getAllTransactions()).single.amount, -420);
      },
    );
  });

  test('currency symbols match the account currency', () {
    expect(NotificationCaptureService.currencyMatches(null, 'EUR'), isTrue);
    expect(NotificationCaptureService.currencyMatches('EUR', 'eur'), isTrue);
    expect(NotificationCaptureService.currencyMatches(r'$', 'CAD'), isTrue);
    expect(NotificationCaptureService.currencyMatches(r'$', 'EUR'), isFalse);
    expect(NotificationCaptureService.currencyMatches('¥', 'JPY'), isTrue);
    expect(NotificationCaptureService.currencyMatches('GBP', 'EUR'), isFalse);
  });
}
