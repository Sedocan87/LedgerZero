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

  void capture(String text, {String? title, String package = 'bank.app'}) {
    channel.queue.add(
      CapturedNotification(
        id: 'n${++nextId}',
        packageName: package,
        appLabel: 'My Bank',
        title: title,
        text: text,
        postedAt: postedAt,
      ),
    );
  }

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
    capture('You spent €12.50 at REWE');

    final result = await service.processPending();

    expect(result.added, 1);
    expect(channel.queue, isEmpty);
    final rows = await t.transactions.getAllTransactions();
    expect(rows, hasLength(1));
    final tx = rows.single;
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

  test('declined payments and balance notices are dropped', () async {
    capture('Your payment of €50.00 at Shell was declined');
    capture('Available balance: €230.00');

    final result = await service.processPending();

    expect(result.ignored, 2);
    expect(channel.queue, isEmpty);
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
    expect(channel.queue, hasLength(2));
  });

  test('captures of an app that is no longer watched are dropped', () async {
    capture('You spent €5.00 at Lidl', package: 'gone.app');

    final result = await service.processPending();

    expect(result.ignored, 1);
    expect(channel.queue, isEmpty);
  });

  test('removing a source drops its pending captures', () async {
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

  test('currency symbols match the account currency', () {
    expect(NotificationCaptureService.currencyMatches(null, 'EUR'), isTrue);
    expect(NotificationCaptureService.currencyMatches('EUR', 'eur'), isTrue);
    expect(NotificationCaptureService.currencyMatches(r'$', 'CAD'), isTrue);
    expect(NotificationCaptureService.currencyMatches(r'$', 'EUR'), isFalse);
    expect(NotificationCaptureService.currencyMatches('¥', 'JPY'), isTrue);
    expect(NotificationCaptureService.currencyMatches('GBP', 'EUR'), isFalse);
  });
}
