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

  test('removing a source drops its waiting captures but keeps its '
      'history', () async {
    channel.sources.add(
      CaptureSource(
        packageName: 'other.app',
        label: 'Other',
        accountId: accountId,
      ),
    );
    final added = capture('You spent €5.00 at Lidl', package: 'other.app');
    await service.processPending();
    final waiting = capture('You have a new message', package: 'other.app');
    capture('You have a new message');

    await service.removeSource('other.app');

    expect(channel.sources.map((s) => s.packageName), ['bank.app']);
    expect(channel.queue.map((n) => n.id), isNot(contains(waiting)));
    expect(statusOf(added), CaptureStatus.added);
    expect(
      (await service.history()).map((e) => e.notification.id),
      contains(added),
    );
  });

  test('the user can delete logged entries; waiting ones stay', () async {
    final booked = capture('You spent €5.00 at Lidl');
    final waiting = capture('You have a new message');
    await service.processPending();

    await service.deleteHistory([booked, waiting]);

    expect(channel.queue.map((n) => n.id), [waiting]);
  });

  test('one entry that throws does not stop the others and is listed '
      'with its error', () async {
    final first = capture('You spent €1.00 at A');
    final bad = capture('You spent €2.00 at B');
    final last = capture('You spent €3.00 at C');
    channel.failSetStatusFor = {bad: StateError('disk full')};

    final result = await service.processPending();

    expect(result.added, 2);
    expect(result.failed, 1);
    expect(statusOf(first), CaptureStatus.added);
    expect(statusOf(last), CaptureStatus.added);
    expect(statusOf(bad), CaptureStatus.failed);
    expect(
      channel.queue.singleWhere((n) => n.id == bad).error,
      'StateError: Bad state: disk full',
    );
    // Not retried on every start: it is no longer pending.
    expect(await channel.pending(), isEmpty);
    expect(await service.held(), isEmpty);

    final entry = (await service.history()).singleWhere(
      (e) => e.notification.id == bad,
    );
    expect(entry.status, CaptureStatus.failed);
    expect(entry.canRetry, isTrue);
    expect(entry.canAdd, isTrue);

    // Retry runs it through the pipeline again. Here the transaction had
    // been saved before the status write failed, so the duplicate check
    // keeps it from being booked twice.
    channel.failSetStatusFor = {};
    final retried = await service.retry([bad]);
    expect(retried.added, 0);
    expect(retried.duplicates, 1);
    expect(statusOf(bad), CaptureStatus.duplicate);
    expect(await t.transactions.getAllTransactions(), hasLength(3));
  });

  group('duplicates', () {
    test('the same amount from a second app within a day is not booked '
        'twice', () async {
      channel.sources.add(
        CaptureSource(
          packageName: 'wallet.app',
          label: 'Wallet',
          accountId: accountId,
        ),
      );
      final wallet = capture(
        '€3.55 at Kiosk',
        package: 'wallet.app',
        at: postedAt.subtract(const Duration(minutes: 1)),
      );
      final bank = capture('Kartenzahlung 3,55 EUR bei Kiosk');

      final result = await service.processPending();

      expect(result.added, 1);
      expect(result.duplicates, 1);
      expect(statusOf(wallet), CaptureStatus.added);
      expect(statusOf(bank), CaptureStatus.duplicate);
      expect(await t.transactions.getAllTransactions(), hasLength(1));

      final entry = (await service.history()).singleWhere(
        (e) => e.notification.id == bank,
      );
      expect(entry.status, CaptureStatus.duplicate);
      expect(entry.likelyDuplicate, isTrue);
      // "Add anyway".
      expect(entry.canAdd, isTrue);
      expect(await service.addAgain([bank]), 1);
      expect(await t.transactions.getAllTransactions(), hasLength(2));
    });

    test('an authorisation followed by the booking is booked once', () async {
      final authorised = capture(
        'Zahlung über 25,00 € bei Aral autorisiert',
        at: postedAt,
      );
      final booked = capture(
        'Zahlung über 25,00 € bei Aral gebucht',
        at: postedAt.add(const Duration(days: 1)),
      );

      await service.processPending();

      expect(statusOf(authorised), CaptureStatus.added);
      expect(statusOf(booked), CaptureStatus.duplicate);
      expect(await t.transactions.getAllTransactions(), hasLength(1));
    });

    test('a transaction entered by hand counts too; two days apart does '
        'not', () async {
      await t.addTransaction(
        accountId: accountId,
        amount: -740,
        date: CalendarDate.normalize(postedAt.add(const Duration(days: 1))),
      );
      await t.addTransaction(
        accountId: accountId,
        amount: -990,
        date: CalendarDate.normalize(postedAt.add(const Duration(days: 2))),
      );
      final dup = capture('You spent €7.40 at Bakery');
      final other = capture('You spent €9.90 at Bakery');

      await service.processPending();

      expect(statusOf(dup), CaptureStatus.duplicate);
      expect(statusOf(other), CaptureStatus.added);
    });
  });

  test('notifications without an amount from Google Play services are '
      'skipped, not held', () async {
    channel.sources.add(
      CaptureSource(
        packageName: 'com.google.android.gms',
        label: 'Google Wallet',
        accountId: accountId,
      ),
    );
    final noise = capture(
      'Nearby Share is ready',
      package: 'com.google.android.gms',
    );
    final payment = capture(
      '€3.55 at Kiosk',
      package: 'com.google.android.gms',
    );

    final result = await service.processPending();

    expect(result.ignored, 1);
    expect(result.added, 1);
    expect(statusOf(noise), CaptureStatus.skipped);
    expect(statusOf(payment), CaptureStatus.added);
    expect(await service.held(), isEmpty);
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

    test('a deleted transaction can be added again; an existing one is '
        'not doubled', () async {
      final id = capture('You spent €12.50 at REWE');
      await service.processPending();
      final tx = (await t.transactions.getAllTransactions()).single;

      var entry = (await service.history()).single;
      // Its own transaction is not a duplicate.
      expect(entry.likelyDuplicate, isFalse);
      expect(entry.transactionDeleted, isFalse);
      expect(entry.canAdd, isFalse);
      expect(await service.addAgain([id]), 0);
      expect(await t.transactions.getAllTransactions(), hasLength(1));

      await t.transactions.deleteTransaction(tx.id);
      entry = (await service.history()).single;
      expect(entry.likelyDuplicate, isFalse);
      expect(entry.transactionDeleted, isTrue);
      expect(entry.canAdd, isTrue);

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
