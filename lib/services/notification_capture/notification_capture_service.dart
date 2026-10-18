import 'dart:async';

import 'package:ledger_zero/core/time/calendar_date.dart';
import 'package:ledger_zero/core/utils/logger.dart';
import 'package:ledger_zero/domain/entities/account.dart';
import 'package:ledger_zero/domain/entities/transaction.dart';
import 'package:ledger_zero/domain/repositories/account_repository.dart';
import 'package:ledger_zero/domain/repositories/payee_repository.dart';
import 'package:ledger_zero/domain/repositories/transaction_repository.dart';
import 'package:ledger_zero/domain/services/transaction_service.dart';
import 'package:ledger_zero/services/notification_capture/card_notification_parser.dart';
import 'package:ledger_zero/services/notification_capture/notification_capture_channel.dart';

/// Why a captured notification did not become a transaction yet.
enum CaptureHoldReason {
  /// No amount could be read.
  unreadable,

  /// The app has no (open) account linked.
  noAccount,

  /// The amount is in another currency than the linked account.
  foreignCurrency,
}

/// A captured notification waiting for the user.
class HeldCapture {
  const HeldCapture(this.notification, this.parse, this.reason);

  final CapturedNotification notification;
  final CardNotificationParse parse;
  final CaptureHoldReason reason;
}

/// A notification in the capture log (see
/// [NotificationCaptureService.history]).
class LoggedCapture {
  const LoggedCapture(
    this.notification,
    this.parse, {
    this.blocker,
    this.likelyDuplicate = false,
    this.transactionDeleted = false,
  });

  final CapturedNotification notification;
  final CardNotificationParse parse;

  /// Why it cannot be added in one tap (it then opens in the transaction
  /// form); `null` when it can.
  final CaptureHoldReason? blocker;

  /// A transaction in the linked account with the same amount within a day
  /// of the notification exists.
  final bool likelyDuplicate;

  /// It was added, but that transaction no longer exists.
  final bool transactionDeleted;

  CaptureStatus get status => notification.status;

  /// Whether [NotificationCaptureService.addAgain] can book it. Pending
  /// ones are booked (or held) by [NotificationCaptureService.processPending];
  /// an added one whose transaction still exists would only be doubled.
  bool get canAdd =>
      blocker == null &&
      status != CaptureStatus.pending &&
      !(status == CaptureStatus.added && !transactionDeleted);

  /// Whether [NotificationCaptureService.retry] runs it through the
  /// pipeline again.
  bool get canRetry => status == CaptureStatus.failed;
}

/// What one [NotificationCaptureService.processPending] run did.
class CaptureRunResult {
  const CaptureRunResult({
    this.added = 0,
    this.ignored = 0,
    this.held = 0,
    this.failed = 0,
    this.duplicates = 0,
  });

  final int added;
  final int ignored;
  final int held;

  /// Entries whose booking threw; they are marked
  /// [CaptureStatus.failed] with the error and can be retried from the log.
  final int failed;

  /// Entries not booked because a transaction with the same amount already
  /// existed ([CaptureStatus.duplicate]).
  final int duplicates;
}

/// Turns captured card notifications into transactions.
///
/// Each notification of a watched app is parsed with
/// [CardNotificationParser]. A payment with an amount, in the currency of
/// the app's linked account, becomes an **unapproved**, uncleared
/// transaction on the day the notification arrived: the payee is the
/// merchant (existing payee by name, else created), the category comes
/// from the user's rules or the payee's last category. The transaction
/// list marks it as not approved until the user approves (swipe) or edits
/// it. Declined payments, codes and balance notices are skipped; anything
/// else is held for the user (see [held]) in the native queue.
///
/// A payment whose amount already exists in the linked account within a
/// day (the wallet app and the bank both notified, or an authorisation was
/// followed by the booking) is logged as [CaptureStatus.duplicate] instead
/// of booked; the user can add it anyway from the log.
///
/// Every entry is handled on its own: when booking one throws, it is
/// marked [CaptureStatus.failed] with the error (and the error is written
/// to the diagnostic log) and the run goes on with the next one.
///
/// Handled notifications stay in the native log for 30 days with their
/// status, so the user can add a skipped or deleted payment again
/// ([history], [addAgain]) or retry a failed one ([retry]).
///
/// Captured transactions are not added to the undo stack.
class NotificationCaptureService {
  NotificationCaptureService({
    required this._channel,
    required this._transactions,
    required this._transactionRepository,
    required this._accounts,
    required this._payees,
    this._parser = const CardNotificationParser(),
  });

  final NotificationCaptureChannel _channel;
  final TransactionService _transactions;
  final TransactionRepository _transactionRepository;
  final AccountRepository _accounts;
  final PayeeRepository _payees;
  final CardNotificationParser _parser;

  /// Apps that post many notifications that are not payments (Google Play
  /// services carries Google Wallet's tap-to-pay notifications on Pixels,
  /// but also everything else): their notifications without an amount
  /// are skipped instead of waiting for the user.
  static const noisyPackages = {'com.google.android.gms'};

  Future<CaptureRunResult>? _running;
  bool _runAgain = false;

  bool get isSupported => _channel.isSupported;

  /// Books every pending notification that can be booked. Concurrent calls
  /// share the running pass, which then runs once more for captures that
  /// arrived meanwhile.
  Future<CaptureRunResult> processPending() {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      return running;
    }
    final run = _process().whenComplete(() {
      _running = null;
      if (_runAgain) {
        _runAgain = false;
        unawaited(processPending());
      }
    });
    _running = run;
    return run;
  }

  /// Pending notifications that could not be booked, oldest first.
  Future<List<HeldCapture>> held() async {
    if (!_channel.isSupported) {
      return const [];
    }
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    final result = <HeldCapture>[];
    for (final n in await _channel.pending()) {
      final parse = _parse(n);
      if (_isNoise(n, parse)) {
        continue;
      }
      final reason = _holdReason(parse, sources[n.packageName], accounts);
      if (reason != null) {
        result.add(HeldCapture(n, parse, reason));
      }
    }
    return result;
  }

  /// Takes held notifications off the waiting list (the user does not
  /// want them); they stay in the log.
  Future<void> dismiss(Iterable<String> ids) =>
      _channel.setStatus(ids, CaptureStatus.dismissed);

  /// Records that the user added [id] by hand (transaction form).
  Future<void> markAdded(String id) =>
      _channel.setStatus([id], CaptureStatus.added);

  /// Logs the notifications of [packageName] that are showing now (they
  /// came before the app was watched); returns how many.
  Future<int> captureShowing(String packageName) =>
      _channel.captureShowing(packageName);

  /// Stops watching [packageName]. Its notifications still waiting are
  /// dropped; handled ones stay in the log (see [deleteHistory]).
  Future<void> removeSource(String packageName) async {
    final sources = await _channel.getSources();
    await _channel.setSources([
      for (final s in sources)
        if (s.packageName != packageName) s,
    ]);
    final pending = await _channel.pending();
    await _channel.remove([
      for (final n in pending)
        if (n.packageName == packageName) n.id,
    ]);
  }

  /// Deletes the logged (handled) notifications [ids]; pending ones stay.
  Future<void> deleteHistory(Iterable<String> ids) async {
    final wanted = ids.toSet();
    final log = await _channel.log();
    await _channel.remove([
      for (final n in log)
        if (wanted.contains(n.id) && n.status != CaptureStatus.pending) n.id,
    ]);
  }

  /// The logged notifications posted in `[from, toExclusive)` (all when
  /// `null`), of [packageName] or of every app, newest first.
  Future<List<LoggedCapture>> history({
    DateTime? from,
    DateTime? toExclusive,
    String? packageName,
  }) async {
    if (!_channel.isSupported) {
      return const [];
    }
    final entries = [
      for (final n in await _channel.log())
        if ((packageName == null || n.packageName == packageName) &&
            (from == null || !n.postedAt.isBefore(from)) &&
            (toExclusive == null || n.postedAt.isBefore(toExclusive)))
          n,
    ];
    if (entries.isEmpty) {
      return const [];
    }
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    final nearby = await _nearbyTransactions(entries);
    final result = <LoggedCapture>[];
    for (final n in entries.reversed) {
      final parse = _parse(n);
      final account = _accountFor(sources[n.packageName], accounts);
      var transactionDeleted = false;
      if (n.status == CaptureStatus.added && n.transactionId != null) {
        transactionDeleted =
            await _transactionRepository.getTransactionById(n.transactionId!) ==
            null;
      }
      result.add(
        LoggedCapture(
          n,
          parse,
          blocker: _blocker(parse, account),
          likelyDuplicate:
              account != null && _hasDuplicate(n, parse, account, nearby),
          transactionDeleted: transactionDeleted,
        ),
      );
    }
    return result;
  }

  /// Books the logged notifications [ids] that can be booked (see
  /// [LoggedCapture.canAdd]), also skipped ones and likely duplicates ("add
  /// anyway"), as unapproved transactions. Returns how many were added.
  Future<int> addAgain(Iterable<String> ids) async {
    final wanted = ids.toSet();
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    var added = 0;
    for (final n in await _channel.log()) {
      if (!wanted.contains(n.id) || n.status == CaptureStatus.pending) {
        continue;
      }
      if (n.status == CaptureStatus.added &&
          n.transactionId != null &&
          await _transactionRepository.getTransactionById(n.transactionId!) !=
              null) {
        // Its transaction still exists; adding would double it.
        continue;
      }
      final parse = _parse(n);
      final account = _accountFor(sources[n.packageName], accounts);
      if (_blocker(parse, account) != null) {
        continue;
      }
      final transaction = await _book(n, parse, account!);
      await _channel.setStatus(
        [n.id],
        CaptureStatus.added,
        transactionId: transaction.id,
      );
      added++;
    }
    return added;
  }

  /// Runs the failed notifications [ids] through the pipeline again.
  Future<CaptureRunResult> retry(Iterable<String> ids) async {
    final wanted = ids.toSet();
    final log = await _channel.log();
    await _channel.setStatus([
      for (final n in log)
        if (wanted.contains(n.id) && n.status == CaptureStatus.failed) n.id,
    ], CaptureStatus.pending);
    return processPending();
  }

  Future<CaptureRunResult> _process() async {
    if (!_channel.isSupported) {
      return const CaptureRunResult();
    }
    final pending = await _channel.pending();
    if (pending.isEmpty) {
      return const CaptureRunResult();
    }
    final sources = await _sourcesByPackage();
    final accounts = await _accountsById();
    final nearby = await _nearbyTransactions(pending);
    var added = 0;
    var ignored = 0;
    var held = 0;
    var failed = 0;
    var duplicates = 0;
    for (final n in pending) {
      try {
        switch (await _handle(n, sources, accounts, nearby)) {
          case _Outcome.added:
            added++;
          case _Outcome.ignored:
            ignored++;
          case _Outcome.held:
            held++;
          case _Outcome.duplicate:
            duplicates++;
        }
      } catch (e, stackTrace) {
        // One bad entry must not stop the others, and the user must be
        // able to see what happened (log screen) and why (diagnostics).
        failed++;
        Logger.error(
          'Card notification ${n.id} from ${n.packageName} '
          '(${_breadcrumb(_parse(n))}) could not be booked',
          e,
          stackTrace,
        );
        try {
          await _channel.setStatus(
            [n.id],
            CaptureStatus.failed,
            error: describeError(e),
          );
        } catch (e2, stackTrace2) {
          Logger.error(
            'Card notification ${n.id} could not be marked as failed',
            e2,
            stackTrace2,
          );
        }
      }
    }
    if (added > 0 || ignored > 0 || failed > 0 || duplicates > 0) {
      Logger.info(
        'Card notifications: $added booked, $ignored skipped, $held held, '
        '$duplicates duplicates, $failed failed',
      );
    }
    return CaptureRunResult(
      added: added,
      ignored: ignored,
      held: held,
      failed: failed,
      duplicates: duplicates,
    );
  }

  Future<_Outcome> _handle(
    CapturedNotification n,
    Map<String, CaptureSource> sources,
    Map<String, Account> accounts,
    List<Transaction> nearby,
  ) async {
    final parse = _parse(n);
    if (parse.kind == CaptureKind.ignored || _isNoise(n, parse)) {
      await _channel.setStatus([n.id], CaptureStatus.skipped);
      return _Outcome.ignored;
    }
    final source = sources[n.packageName];
    if (source == null) {
      // The app is no longer watched; its captures are not wanted.
      await _channel.remove([n.id]);
      return _Outcome.ignored;
    }
    if (_holdReason(parse, source, accounts) != null) {
      return _Outcome.held;
    }
    final account = accounts[source.accountId]!;
    if (_hasDuplicate(n, parse, account, nearby)) {
      await _channel.setStatus([n.id], CaptureStatus.duplicate);
      return _Outcome.duplicate;
    }
    final transaction = await _book(n, parse, account);
    // Marked right after the save, so a crash in between can at worst
    // book this one notification twice.
    await _channel.setStatus(
      [n.id],
      CaptureStatus.added,
      transactionId: transaction.id,
    );
    // The next entry of this run may be the same payment from another app.
    nearby.add(transaction);
    return _Outcome.added;
  }

  /// Saves [n] as an unapproved transaction.
  Future<Transaction> _book(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
  ) async {
    final date = CalendarDate.normalize(n.postedAt);
    final amount = parse.signedAmount!;
    final merchant = parse.merchant;
    final suggested = await _transactions.suggestWithRules(
      Transaction(
        id: 'notification-capture',
        accountId: account.id,
        date: date,
        amount: amount,
        // Without a merchant the notification text tells the user what
        // the transaction was.
        memo: merchant == null ? _memoFrom(n) : null,
      ),
      payeeName: merchant,
    );
    final payeeId =
        suggested.payeeId ?? await _transactions.resolvePayee(name: merchant);
    var categoryId = suggested.categoryId;
    if (categoryId == null && payeeId != null) {
      categoryId = (await _payees.getPayeeById(payeeId))?.autoCategoryId;
    }
    final saved = await _transactions.save(
      TransactionInput(
        accountId: account.id,
        date: date,
        amount: amount,
        payeeId: payeeId,
        categoryId: categoryId,
        memo: suggested.memo,
        approved: false,
      ),
      recordUndo: false,
    );
    return (await _transactionRepository.getTransactionById(saved.id)) ??
        Transaction(
          id: saved.id,
          accountId: account.id,
          date: date,
          amount: amount,
          approved: false,
        );
  }

  /// The transactions around the days of [entries], for duplicate checks.
  Future<List<Transaction>> _nearbyTransactions(
    List<CapturedNotification> entries,
  ) async {
    final dates = entries.map((n) => CalendarDate.normalize(n.postedAt));
    final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
    return (await _transactionRepository.getTransactionsByDateRange(
      earliest.subtract(const Duration(days: 1)),
      latest.add(const Duration(days: 2)),
      excludeSplitChildren: true,
    )).where((t) => !t.isDeleted).toList();
  }

  /// Whether [account] holds a transaction with the amount of [parse]
  /// within a day of [n]; an added entry's own transaction does not count.
  static bool _hasDuplicate(
    CapturedNotification n,
    CardNotificationParse parse,
    Account account,
    List<Transaction> nearby,
  ) {
    final amount = parse.signedAmount;
    if (amount == null) {
      return false;
    }
    final date = CalendarDate.normalize(n.postedAt);
    return nearby.any(
      (t) =>
          t.accountId == account.id &&
          t.amount == amount &&
          t.id != n.transactionId &&
          t.date.difference(date).inDays.abs() <= 1,
    );
  }

  CardNotificationParse _parse(CapturedNotification n) =>
      _parser.parse(title: n.title, text: n.text, appLabel: n.appLabel);

  /// A notification without an amount from a [noisyPackages] app.
  static bool _isNoise(CapturedNotification n, CardNotificationParse parse) =>
      parse.kind == CaptureKind.unreadable &&
      noisyPackages.contains(n.packageName);

  CaptureHoldReason? _holdReason(
    CardNotificationParse parse,
    CaptureSource? source,
    Map<String, Account> accounts,
  ) {
    if (parse.kind == CaptureKind.ignored) {
      return null;
    }
    return _blocker(parse, _accountFor(source, accounts));
  }

  /// Why [parse] cannot be booked to [account] (the open account linked
  /// to its app), ignoring whether it looked like a booking.
  static CaptureHoldReason? _blocker(
    CardNotificationParse parse,
    Account? account,
  ) {
    if (parse.amount == null) {
      return CaptureHoldReason.unreadable;
    }
    if (account == null) {
      return CaptureHoldReason.noAccount;
    }
    if (!currencyMatches(parse.currency, account.currency)) {
      return CaptureHoldReason.foreignCurrency;
    }
    return null;
  }

  /// The account [source] books to, unless missing, closed or the
  /// partner's.
  static Account? _accountFor(
    CaptureSource? source,
    Map<String, Account> accounts,
  ) {
    final account = source?.accountId == null
        ? null
        : accounts[source!.accountId];
    if (account == null || account.isClosed || account.isPartners) {
      return null;
    }
    return account;
  }

  /// Whether a notification [currency] (code, symbol or `null`) can be
  /// booked to an account in [accountCurrency].
  static bool currencyMatches(String? currency, String accountCurrency) {
    if (currency == null) {
      return true;
    }
    final account = accountCurrency.toUpperCase();
    return switch (currency) {
      r'$' => const {
        'USD',
        'CAD',
        'AUD',
        'NZD',
        'SGD',
        'HKD',
        'MXN',
      }.contains(account),
      '¥' => account == 'JPY' || account == 'CNY',
      _ => currency.toUpperCase() == account,
    };
  }

  /// What the parser made of a notification, without its text.
  static String _breadcrumb(CardNotificationParse parse) =>
      '${parse.kind.name}, amount ${parse.amount ?? '-'} '
      '${parse.currency ?? ''}, merchant ${parse.merchant == null ? 'no' : 'yes'}'
      '${parse.ignoredPhrase == null ? '' : ', phrase "${parse.ignoredPhrase}"'}';

  /// The error class and message, short enough for the log entry.
  static String describeError(Object error) {
    final text = error.toString();
    final type = error.runtimeType.toString();
    final described = text.startsWith(type) ? text : '$type: $text';
    return described.length <= 200
        ? described
        : '${described.substring(0, 199)}…';
  }

  static String _memoFrom(CapturedNotification n) {
    final text = [n.title, n.text]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(': ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length <= 120 ? text : '${text.substring(0, 119)}…';
  }

  Future<Map<String, CaptureSource>> _sourcesByPackage() async => {
    for (final s in await _channel.getSources()) s.packageName: s,
  };

  Future<Map<String, Account>> _accountsById() async => {
    for (final a in await _accounts.getAllAccounts()) a.id: a,
  };
}

enum _Outcome { added, ignored, held, duplicate }
